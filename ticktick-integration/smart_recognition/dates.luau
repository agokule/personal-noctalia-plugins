--!nonstrict
-- Date recognition: "today", "tomorrow", "next friday", "6 january",
-- "march 6, 2026", "3/6", "2026-12-25".
--
-- A match sets plan.date and plan.dateKind. The kind says how to roll a date
-- that has already passed once the time is known: a weekday rolls a week, a
-- day-and-month rolls a year, and a date the user spelled out in full stays
-- put.

local Calendar = require("./calendar.luau")
local Scanner = require("./scanner.luau")
local Vocabulary = require("./vocabulary.luau")

local function setDate(state, plan, s: number, e: number, date: Calendar.Moment, kind: string)
  plan.date = date
  plan.dateKind = kind
  Scanner.record(state, "date", Scanner.extendLeft(state, s, Vocabulary.DATE_PREFIXES), e)
  return true
end

-- "next monday" is the Monday of the following week; "monday" is the soonest
-- Monday that has not passed yet (today counts).
local RELATIVE_DATE_RULES = {
  { pat = "the%s+day%s+after%s+tomorrow", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, 2), "explicit")
  end },
  { pat = "day%s+after%s+tomorrow", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, 2), "explicit")
  end },
  { pat = "tomorrow", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, 1), "explicit")
  end },
  { pat = "tmrw", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, 1), "explicit")
  end },
  { pat = "tmr", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, 1), "explicit")
  end },
  { pat = "yesterday", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, -1), "explicit")
  end },
  { pat = "today", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.copyMoment(plan.now), "explicit")
  end },
  { pat = "tonight", fn = function(state, plan, s, e)
    plan.defaultHour = 20
    return setDate(state, plan, s, e, Calendar.copyMoment(plan.now), "explicit")
  end },
  { pat = "tod", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.copyMoment(plan.now), "explicit")
  end },
  { pat = "td", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.copyMoment(plan.now), "explicit")
  end },
  { pat = "next%s+week", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addDays(plan.now, 7), "explicit")
  end },
  { pat = "next%s+month", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addMonths(plan.now, 1), "explicit")
  end },
  { pat = "next%s+year", fn = function(state, plan, s, e)
    return setDate(state, plan, s, e, Calendar.addMonths(plan.now, 12), "explicit")
  end },
  { pat = "next%s+(%a+)", fn = function(state, plan, s, e, word)
    local wd = Vocabulary.WEEKDAYS[word]
    if not wd then return false end
    -- the same weekday next week, counted from this week's Monday
    local weekStart = Calendar.addDays(plan.now, -((Calendar.weekdayOf(plan.now) + 6) % 7))
    return setDate(state, plan, s, e, Calendar.nextWeekday(Calendar.addDays(weekStart, 7), wd), "explicit")
  end },
  { pat = "this%s+(%a+)", fn = function(state, plan, s, e, word)
    local wd = Vocabulary.WEEKDAYS[word]
    if not wd then return false end
    return setDate(state, plan, s, e, Calendar.nextWeekday(plan.now, wd), "weekday")
  end },
}

local WEEKDAY_DATE_RULES = {
  { pat = "(%a+)", fn = function(state, plan, s, e, word)
    local wd = Vocabulary.WEEKDAYS[word]
    if not wd then return false end
    return setDate(state, plan, s, e, Calendar.nextWeekday(plan.now, wd), "weekday")
  end },
}

local function makeNumericDate(order)
  return function(state, plan, s, e, a, b, c)
    local before, after = "", ""
    if s > 1 then before = string.sub(state.lower, s - 1, s - 1) end
    if e < #state.lower then after = string.sub(state.lower, e + 1, e + 1) end
    if string.match(before, "[%-/:]") or string.match(after, "[%-/:]") then return false end
    local n1, n2, n3 = tonumber(a), tonumber(b), tonumber(c)
    local y, m, d
    if order == "ymd" then
      y, m, d = n1, n2, n3
    else
      m, d, y = n1, n2, n3
      if m > 12 and d <= 12 then m, d = d, m end -- accept day-first input too
      if y and y < 100 then y += 2000 end
    end
    if not m or not d or m < 1 or m > 12 or d < 1 then return false end
    if y then
      if d > Calendar.daysInMonth(y, m) then return false end
      return setDate(state, plan, s, e, Calendar.moment(y, m, d), "explicit")
    end
    if d > Calendar.daysInMonth(plan.now.year, m) and d > Calendar.daysInMonth(plan.now.year + 1, m) then return false end
    return setDate(state, plan, s, e, Calendar.nextYearDay(plan.now, m, d), "monthday")
  end
end

local NUMERIC_DATE_RULES = {
  { pat = "(%d%d%d%d)%-(%d%d?)%-(%d%d?)", fn = makeNumericDate("ymd") },
  { pat = "(%d%d%d%d)/(%d%d?)/(%d%d?)", fn = makeNumericDate("ymd") },
  { pat = "(%d%d?)/(%d%d?)/(%d%d%d%d)", fn = makeNumericDate("mdy") },
  { pat = "(%d%d?)/(%d%d?)/(%d%d)", fn = makeNumericDate("mdy") },
  { pat = "(%d%d?)/(%d%d?)", fn = makeNumericDate("mdy") },
  { pat = "(%d%d?)%-(%d%d?)", fn = makeNumericDate("mdy") },
}

-- "6 march", "6th of march", "march 6", "march 6, 2026", "jan"
local function extractMonthDate(state, plan)
  for s, word, nextPos in string.gmatch(state.lower, "()(%a+)()") do
    local month = Vocabulary.MONTHS[word]
    if month then
      local e = nextPos - 1
      local startIdx, endIdx = s, e
      local day, year = nil, nil
      local prefix = string.sub(state.lower, 1, s - 1)

      local dpos, dnum, ord = string.match(prefix, "()(%d%d?)(%a?%a?)%s+of%s+$")
      if not dpos then
        dpos, dnum, ord = string.match(prefix, "()(%d%d?)(%a?%a?)%s+$")
      end
      if dpos and Vocabulary.ORDINALS[ord] and not string.match(string.sub(prefix, dpos - 1, dpos - 1), "%d") then
        day = tonumber(dnum)
        startIdx = dpos
      end

      if not day then
        local ds, de, dnum2, ord2 = string.find(state.lower, "^,?%s+(%d%d?)(%a?%a?)", e + 1)
        local nextChar = ""
        if de and de < #state.lower then nextChar = string.sub(state.lower, de + 1, de + 1) end
        if ds and Vocabulary.ORDINALS[ord2] and not string.match(nextChar, "[%d:]") then
          day = tonumber(dnum2)
          endIdx = de
        end
      end

      local ys, ye, ynum = string.find(state.lower, "^,?%s+(%d%d%d%d)", endIdx + 1)
      if ys then
        year = tonumber(ynum)
        endIdx = ye
      end

      -- A bare month name means the 1st; "may" is too common a word to take alone.
      local ok = day ~= nil or year ~= nil or word ~= "may"
      if day and day > Calendar.daysInMonth(year or 2024, month) then ok = false end
      if ok then
        local d = day or 1
        if year then
          return setDate(state, plan, startIdx, endIdx, Calendar.moment(year, month, d), "explicit")
        end
        return setDate(state, plan, startIdx, endIdx, Calendar.nextYearDay(plan.now, month, d), "monthday")
      end
    end
  end
  return false
end

local function extractDate(state, plan)
  if Scanner.scanRules(state, RELATIVE_DATE_RULES, plan) then return true end
  if extractMonthDate(state, plan) then return true end
  if Scanner.scanRules(state, NUMERIC_DATE_RULES, plan) then return true end
  if Scanner.scanRules(state, WEEKDAY_DATE_RULES, plan) then return true end
  return false
end

return { extract = extractDate }
