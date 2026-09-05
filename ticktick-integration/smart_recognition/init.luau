--!nonstrict
--
-- Quick-add text parser for TickTick's Smart Recognition
-- (https://help.ticktick.com/articles/7081924556310446080), plus the quick-add
-- markers that page does not document:
--
--   !<priority>  none | low | medium | high (also n/l/m/h and 0/1/2/3)
--   #<tag>       a single word of letters, digits, "-" and "_"
--   ~<list>      or ^<list>; fuzzy matched against the known list names.
--                Quote it (~"My List") when the name has spaces.
--
-- Everything recognised is stripped out of the task title.
--
-- Dates and times resolve to the "next effective" moment, i.e. the soonest one
-- that is not already in the past:
--
--   today / tod / td, tomorrow / tmr, yesterday, the day after tomorrow
--   monday / mon, next monday, this friday, next week / month / year
--   january / jan                -> the 1st of the next effective January
--   6 january, jan 6, 3/6, 03/06, 3-6, 2026-03-06, 6 march 2026
--   9am, 9 am, 09:00, 9:00, at 9, noon, morning, afternoon, evening, midnight
--   9am - 10am, 9am to 10am      -> startDate + dueDate
--   6 march, 9pm / march 6 at 9pm
--
--   every day, every 2 days, every week, every 2 weeks, every month,
--   every year, every monday, every weekday, every weekend, daily, weekly,
--   6 march every year, march every year, 1st day of the month,
--   last day of the month        -> RRULE plus the implied start date
--
--   in 5 minutes, 5 minutes later, after 1 hour 30 minutes -> due now + delta
--   remind 3 mins earlier, remind me in advance            -> early reminder
--
-- Two rows of the help page's table are typos in the original and are
-- implemented as written here: "Afternoon" is 1 pm (the page says "1 am") and
-- "Evening" is 17:00 (the page says "17 pm").

local Calendar = require("./calendar.luau")
local Scanner = require("./scanner.luau")
local Markers = require("./markers.luau")
local Repeats = require("./repeats.luau")
local Reminders = require("./reminders.luau")
local Dates = require("./dates.luau")
local Times = require("./times.luau")

export type ParsedTask = {
  title: string, -- input with every recognised token removed
  raw: string,
  priority: number, -- TickTick values: 0 none, 1 low, 3 medium, 5 high
  priorityName: string,
  tags: { string },
  list: string?, -- best match out of the `lists` argument
  listQuery: string?, -- what was actually typed after ~ or ^
  startDate: Calendar.Moment?, -- only set for time ranges ("9am - 10am")
  dueDate: Calendar.Moment?,
  isAllDay: boolean,
  repeatFlag: string?, -- "RRULE:FREQ=..."
  reminders: { string }, -- "TRIGGER:..." entries
  matches: { Scanner.Match }, -- every recognised span, for previews
}

-- Every extractor writes into one shared `plan`:
--
--   now                     the Moment the parse is relative to
--   date, dateKind          an explicit date, and how to roll it if it passed
--   hour, min               a recognised time
--   endHour, endMin         the far end of a time range
--   ambiguousHour           the hour came from a bare "at 9"
--   defaultHour             an hour implied by the date word ("tonight")
--   absolute                an already-resolved Moment ("in 5 minutes")
--   repeatFlag, repeatStart the recurrence and the date it starts on
--   early, onTime           reminders to attach once there is a due date
--
-- resolve() is what turns all of that into dueDate / startDate / isAllDay.

local function resolve(plan, out)
  local now = plan.now

  if plan.absolute then
    out.dueDate = plan.absolute
    out.isAllDay = false
  else
    local date = plan.date or plan.repeatStart
    local hasTime = plan.hour ~= nil or plan.defaultHour ~= nil
    if not date and not hasTime then return end

    local hour, min = plan.hour, plan.min
    if hour == nil then
      hour, min = plan.defaultHour, 0
    end

    local base
    if date then
      base = Calendar.moment(date.year, date.month, date.day, hour or 0, min or 0)
    else
      base = Calendar.moment(now.year, now.month, now.day, hour or 0, min or 0)
    end

    if hasTime and plan.ambiguousHour and hour and hour < 12 then
      -- "at 9" means whichever of 9:00 / 21:00 comes first
      local pmBase = Calendar.copyMoment(base)
      pmBase.hour = hour + 12
      if Calendar.isBefore(base, now) and not Calendar.isBefore(pmBase, now) then base = pmBase end
    end

    if Calendar.isBefore(base, now) then
      if not date then
        base = Calendar.addDays(base, 1)
      elseif plan.dateKind == "weekday" then
        base = Calendar.addDays(base, 7)
      elseif plan.dateKind == "monthday" then
        base = Calendar.addMonths(base, 12)
      end
    end

    out.isAllDay = not hasTime
    out.dueDate = base
    if plan.endHour then
      local finish = Calendar.copyMoment(base)
      finish.hour, finish.min = plan.endHour, plan.endMin
      if Calendar.momentMinutes(finish) <= Calendar.momentMinutes(base) then finish = Calendar.addDays(finish, 1) end
      out.startDate = base
      out.dueDate = finish
    end
  end

  out.repeatFlag = plan.repeatFlag
  if out.dueDate and (plan.early or plan.onTime) then
    table.insert(out.reminders, "TRIGGER:PT0S") -- on time, as the help page describes
    if plan.early then table.insert(out.reminders, plan.early) end
  end
end

--[[
  Parses TickTick quick-add text.

    text  the raw launcher input
    lists optional array of the user's list names; the ~ / ^ marker is fuzzy
          matched against them and the best one is returned in `list`
    now   optional Calendar.Moment to parse relative to (defaults to the local clock)

  Returns a ParsedTask; every recognised token is removed from `title`.
]]
local function parseTask(text: string, lists: { string }?, now: Calendar.Moment?): ParsedTask
  local out: ParsedTask = {
    title = "",
    raw = text,
    priority = 0,
    priorityName = "none",
    tags = {},
    list = nil,
    listQuery = nil,
    startDate = nil,
    dueDate = nil,
    isAllDay = false,
    repeatFlag = nil,
    reminders = {},
    matches = {},
  }

  local state = Scanner.new(text)
  local plan = { now = now or Calendar.nowMoment() }

  Markers.extract(state, out, lists)
  Repeats.extract(state, plan)
  Reminders.extract(state, plan)
  if not plan.absolute then
    Dates.extract(state, plan)
    Times.extract(state, plan)
    -- "at 9pm" with no date but a repeat rule still starts on the repeat's date
  end

  resolve(plan, out)
  out.title = Scanner.cleanTitle(state.text)
  out.matches = state.matches
  return out
end

-- A one-line summary of what was recognised, for the launcher subtitle.
local function describeTask(task: ParsedTask): string
  local parts = {}
  if task.startDate then
    table.insert(parts, Calendar.formatMoment(task.startDate) .. " - " .. Calendar.formatMoment(task.dueDate))
  elseif task.dueDate then
    table.insert(parts, Calendar.formatMoment(task.dueDate, task.isAllDay))
  end
  if task.repeatFlag then
    table.insert(parts, (string.gsub(task.repeatFlag, "^RRULE:", "repeats ")))
  end
  if #task.reminders > 1 then
    table.insert(parts, "reminder " .. task.reminders[2])
  end
  if task.priority ~= 0 then
    table.insert(parts, task.priorityName .. " priority")
  end
  for _, tag in ipairs(task.tags) do
    table.insert(parts, "#" .. tag)
  end
  if task.list then
    table.insert(parts, "in " .. task.list)
  elseif task.listQuery then
    table.insert(parts, "list " .. task.listQuery .. "?")
  end
  if #parts == 0 then return "No date, inbox, no priority" end
  return table.concat(parts, "  ·  ")
end

return {
  parseTask = parseTask,
  describeTask = describeTask,
  momentToIso = Calendar.momentToIso,
  formatMoment = Calendar.formatMoment,
}
