--!nonstrict
-- The words Smart Recognition knows, and the values they map to.

local MONTHS = {
  january = 1, jan = 1, february = 2, feb = 2, march = 3, mar = 3,
  april = 4, apr = 4, may = 5, june = 6, jun = 6, july = 7, jul = 7,
  august = 8, aug = 8, september = 9, sept = 9, sep = 9, october = 10, oct = 10,
  november = 11, nov = 11, december = 12, dec = 12,
}

-- 0 = Sunday, matching weekdayOf() below.
local WEEKDAYS = {
  sunday = 0, sun = 0, monday = 1, mon = 1, tuesday = 2, tue = 2, tues = 2,
  wednesday = 3, wed = 3, weds = 3, thursday = 4, thu = 4, thur = 4, thurs = 4,
  friday = 5, fri = 5, saturday = 6, sat = 6,
}

local DAY_CODES = { "SU", "MO", "TU", "WE", "TH", "FR", "SA" }

-- Deliberately no bare single letters, and no "mo"/"mon" (that is Monday).
local UNITS = {
  minute = "minute", minutes = "minute", min = "minute", mins = "minute",
  hour = "hour", hours = "hour", hr = "hour", hrs = "hour",
  day = "day", days = "day", week = "week", weeks = "week",
  month = "month", months = "month", year = "year", years = "year", yr = "year", yrs = "year",
}

local PRIORITY_VALUES = { none = 0, low = 1, medium = 3, high = 5 }
local PRIORITY_WORDS = {
  none = "none", n = "none", ["0"] = "none",
  low = "low", l = "low", ["1"] = "low",
  medium = "medium", med = "medium", m = "medium", mid = "medium", ["2"] = "medium",
  high = "high", h = "high", hi = "high", ["3"] = "high", urgent = "high",
}

local ORDINALS = { [""] = true, st = true, nd = true, rd = true, th = true }
local DATE_PREFIXES = { on = true, by = true, due = true, the = true, of = true, ["in"] = true, ["for"] = true }
local TIME_PREFIXES = { at = true, from = true, ["@"] = true, around = true, between = true }

return {
  MONTHS = MONTHS,
  WEEKDAYS = WEEKDAYS,
  DAY_CODES = DAY_CODES,
  UNITS = UNITS,
  PRIORITY_VALUES = PRIORITY_VALUES,
  PRIORITY_WORDS = PRIORITY_WORDS,
  ORDINALS = ORDINALS,
  DATE_PREFIXES = DATE_PREFIXES,
  TIME_PREFIXES = TIME_PREFIXES,
}
