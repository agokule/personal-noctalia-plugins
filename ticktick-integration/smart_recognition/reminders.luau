--!nonstrict
-- The "Early reminder" and "Postponed reminder" tables of the Smart
-- Recognition page.
--
-- "remind 3 mins earlier" sets plan.early to a TRIGGER; "in 5 minutes" and
-- "1 hour 30 minutes later" instead resolve the due date outright into
-- plan.absolute. Both ask for the on-time reminder the page describes.

local Calendar = require("./calendar.luau")
local Scanner = require("./scanner.luau")
local Vocabulary = require("./vocabulary.luau")

local function triggerFor(n: number, unit: string): string?
  if unit == "minute" then return string.format("TRIGGER:-PT%dM", n) end
  if unit == "hour" then return string.format("TRIGGER:-PT%dH", n) end
  if unit == "day" then return string.format("TRIGGER:-P%dD", n) end
  if unit == "week" then return string.format("TRIGGER:-P%dW", n) end
  return nil
end

local EARLY_WORDS = { "earlier", "early", "ahead", "beforehand", "in%s+advance" }
local REMIND_FILLER = { remind = true, me = true, reminder = true, us = true }

local function consumeRemindPrefix(state, s: number): number
  local at = s
  for _ = 1, 2 do
    at = Scanner.extendLeft(state, at, REMIND_FILLER)
  end
  return at
end

-- "remind 3 mins earlier", "3 days early", "remind me in advance"
local function extractEarlyReminder(state, plan)
  for _, tail in ipairs(EARLY_WORDS) do
    local s, e, num, unitWord = Scanner.findWord(state.lower, "(%d+)%s*(%a+)%.?%s+" .. tail)
    if s then
      local unit = Vocabulary.UNITS[unitWord]
      local n = tonumber(num)
      local trigger = nil
      if unit and n then trigger = triggerFor(n, unit) end
      if trigger then
        plan.early = trigger
        Scanner.record(state, "reminder", consumeRemindPrefix(state, s), e)
        return true
      end
    end
  end
  local s, e = Scanner.findWord(state.lower, "in%s+advance")
  if s then
    plan.early = "TRIGGER:-PT5M" -- TickTick's default early reminder
    local from = consumeRemindPrefix(state, s)
    local _, oe = string.find(state.lower, "^%s+of", e + 1)
    if oe then e = oe end
    Scanner.record(state, "reminder", from, e)
    return true
  end
  return false
end

-- "in 5 minutes", "5 minutes later", "after 1 hour 30 minutes"
local DURATION_RULES = {
  { pat = "(%d+)%s*(%a+)%s+(%d+)%s*(%a+)%s+later", pairs2 = true },
  { pat = "in%s+(%d+)%s*(%a+)%s+(%d+)%s*(%a+)", pairs2 = true },
  { pat = "after%s+(%d+)%s*(%a+)%s+(%d+)%s*(%a+)", pairs2 = true },
  { pat = "(%d+)%s*(%a+)%s+later" },
  { pat = "in%s+(%d+)%s*(%a+)" },
  { pat = "after%s+(%d+)%s*(%a+)" },
}

local function applyDuration(base: Calendar.Moment, n: number, unit: string): Calendar.Moment?
  if unit == "minute" then return Calendar.addMinutes(base, n) end
  if unit == "hour" then return Calendar.addMinutes(base, n * 60) end
  if unit == "day" then return Calendar.addDays(base, n) end
  if unit == "week" then return Calendar.addDays(base, n * 7) end
  if unit == "month" then return Calendar.addMonths(base, n) end
  if unit == "year" then return Calendar.addMonths(base, n * 12) end
  return nil
end

local function extractDuration(state, plan)
  for _, rule in ipairs(DURATION_RULES) do
    local at = 1
    while true do
      local res = { Scanner.findWord(state.lower, rule.pat, at) }
      local s, e = res[1], res[2]
      if not s then break end
      local n1, u1 = tonumber(res[3]), Vocabulary.UNITS[res[4]]
      local ok = n1 ~= nil and u1 ~= nil
      local target = nil
      if ok then
        target = applyDuration(plan.now, n1, u1)
        if rule.pairs2 then
          local n2, u2 = tonumber(res[5]), Vocabulary.UNITS[res[6]]
          if n2 and u2 and target then
            target = applyDuration(target, n2, u2)
          else
            target = nil
          end
        end
      end
      if target then
        plan.absolute = target
        plan.onTime = true
        Scanner.record(state, "date", s, e)
        return true
      end
      at = s + 1
    end
  end
  return false
end

-- Early reminders first: "remind 3 mins earlier" would otherwise read as the
-- "3 mins later" delay below.
local function extract(state, plan)
  extractEarlyReminder(state, plan)
  extractDuration(state, plan)
end

return { extract = extract }
