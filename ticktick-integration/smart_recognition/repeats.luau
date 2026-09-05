--!nonstrict
-- The "Repeat" table of TickTick's Smart Recognition page: "every day",
-- "every 2 weeks", "every weekday", "6 march every year", "1st day of the
-- month" and friends.
--
-- A match sets plan.repeatFlag (an RRULE) plus plan.repeatStart, the date the
-- page says the recurrence starts on. The start date is only used when the
-- text carries no date of its own.

local Calendar = require("./calendar.luau")
local Scanner = require("./scanner.luau")
local Vocabulary = require("./vocabulary.luau")

local WEEKDAY_SET = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }
local WEEKEND_SET = { [0] = true, [6] = true }

local function setRepeat(state, plan, s: number, e: number, rrule: string, start: Calendar.Moment?)
  plan.repeatFlag = "RRULE:" .. rrule
  plan.repeatStart = start
  Scanner.record(state, "repeat", Scanner.extendLeft(state, s, { repeated = true, repeats = true, repeat_ = true }), e)
  return true
end

local REPEAT_RULES = {
  -- "1st day of the month" / "last day of the month"
  {
    pat = "last%s+day%s+of%s+the%s+month",
    fn = function(state, plan, s, e)
      return setRepeat(state, plan, s, e, "FREQ=MONTHLY;BYMONTHDAY=-1", Calendar.nextMonthDay(plan.now, -1))
    end,
  },
  {
    pat = "(%d+)(%a*)%s+day%s+of%s+the%s+month",
    fn = function(state, plan, s, e, num, ord)
      if not Vocabulary.ORDINALS[ord] then return false end
      local d = tonumber(num)
      if not d or d < 1 or d > 31 then return false end
      return setRepeat(state, plan, s, e, "FREQ=MONTHLY;BYMONTHDAY=" .. d, Calendar.nextMonthDay(plan.now, d))
    end,
  },
  -- "6 march every year" / "every 6 march"
  {
    pat = "(%d+)(%a*)%s+(%a+)%s+every%s+year",
    fn = function(state, plan, s, e, num, ord, monthWord)
      local month = Vocabulary.MONTHS[monthWord]
      local d = tonumber(num)
      if not month or not d or not Vocabulary.ORDINALS[ord] or d > Calendar.daysInMonth(2024, month) then return false end
      return setRepeat(
        state, plan, s, e,
        string.format("FREQ=YEARLY;BYMONTH=%d;BYMONTHDAY=%d", month, d),
        Calendar.nextYearDay(plan.now, month, d)
      )
    end,
  },
  {
    pat = "every%s+(%d+)(%a*)%s+(%a+)",
    fn = function(state, plan, s, e, num, ord, monthWord)
      local month = Vocabulary.MONTHS[monthWord]
      local d = tonumber(num)
      if not month or not d or not Vocabulary.ORDINALS[ord] or d > Calendar.daysInMonth(2024, month) then return false end
      return setRepeat(
        state, plan, s, e,
        string.format("FREQ=YEARLY;BYMONTH=%d;BYMONTHDAY=%d", month, d),
        Calendar.nextYearDay(plan.now, month, d)
      )
    end,
  },
  -- "march every year" / "every march" -> the 1st of that month
  {
    pat = "(%a+)%s+every%s+year",
    fn = function(state, plan, s, e, monthWord)
      local month = Vocabulary.MONTHS[monthWord]
      if not month then return false end
      return setRepeat(
        state, plan, s, e,
        string.format("FREQ=YEARLY;BYMONTH=%d;BYMONTHDAY=1", month),
        Calendar.nextYearDay(plan.now, month, 1)
      )
    end,
  },
  {
    pat = "each%s+(%a+)",
    fn = function(state, plan, s, e, monthWord)
      local month = Vocabulary.MONTHS[monthWord]
      if not month then return false end
      return setRepeat(
        state, plan, s, e,
        string.format("FREQ=YEARLY;BYMONTH=%d;BYMONTHDAY=1", month),
        Calendar.nextYearDay(plan.now, month, 1)
      )
    end,
  },
  -- weekday / weekend sets, before the plain "every week" rule
  {
    pat = "every%s+week%s*day",
    fn = function(state, plan, s, e)
      return setRepeat(
        state, plan, s, e, "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        Calendar.nextWeekdayIn(plan.now, WEEKDAY_SET)
      )
    end,
  },
  {
    pat = "every%s+work%s*day",
    fn = function(state, plan, s, e)
      return setRepeat(
        state, plan, s, e, "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        Calendar.nextWeekdayIn(plan.now, WEEKDAY_SET)
      )
    end,
  },
  {
    pat = "every%s+week%s*end",
    fn = function(state, plan, s, e)
      return setRepeat(
        state, plan, s, e, "FREQ=WEEKLY;BYDAY=SA,SU",
        Calendar.nextWeekdayIn(plan.now, WEEKEND_SET)
      )
    end,
  },
  -- "every 2 days" and friends
  {
    pat = "every%s+(%d+)%s*(%a+)",
    fn = function(state, plan, s, e, num, unitWord)
      local unit = Vocabulary.UNITS[unitWord]
      local n = tonumber(num)
      if not unit or not n or n < 1 then return false end
      local freq = ({ day = "DAILY", week = "WEEKLY", month = "MONTHLY", year = "YEARLY" })[unit]
      if not freq then return false end
      local rrule = "FREQ=" .. freq
      if n > 1 then rrule ..= ";INTERVAL=" .. n end
      return setRepeat(state, plan, s, e, rrule, Calendar.copyMoment(plan.now))
    end,
  },
  -- "every monday"
  {
    pat = "every%s+(%a+)",
    fn = function(state, plan, s, e, dayWord)
      local wd = Vocabulary.WEEKDAYS[dayWord]
      if not wd then return false end
      return setRepeat(
        state, plan, s, e,
        "FREQ=WEEKLY;BYDAY=" .. Vocabulary.DAY_CODES[wd + 1],
        Calendar.nextWeekday(plan.now, wd)
      )
    end,
  },
  { pat = "every%s+other%s+day", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=DAILY;INTERVAL=2", Calendar.copyMoment(plan.now))
  end },
  { pat = "every%s+day", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=DAILY", Calendar.copyMoment(plan.now))
  end },
  { pat = "everyday", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=DAILY", Calendar.copyMoment(plan.now))
  end },
  { pat = "daily", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=DAILY", Calendar.copyMoment(plan.now))
  end },
  -- "every week" starts on the nearest Monday, per the help page
  { pat = "every%s+week", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=WEEKLY", Calendar.nextWeekday(plan.now, 1))
  end },
  { pat = "weekly", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=WEEKLY", Calendar.nextWeekday(plan.now, 1))
  end },
  { pat = "every%s+month", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=MONTHLY", Calendar.copyMoment(plan.now))
  end },
  { pat = "monthly", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=MONTHLY", Calendar.copyMoment(plan.now))
  end },
  { pat = "every%s+year", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=YEARLY", Calendar.copyMoment(plan.now))
  end },
  { pat = "yearly", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=YEARLY", Calendar.copyMoment(plan.now))
  end },
  { pat = "annually", fn = function(state, plan, s, e)
    return setRepeat(state, plan, s, e, "FREQ=YEARLY", Calendar.copyMoment(plan.now))
  end },
}

local function extract(state, plan): boolean
  return Scanner.scanRules(state, REPEAT_RULES, plan)
end

return { extract = extract }
