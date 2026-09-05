--!nonstrict
-- Calendar arithmetic for the quick-add parser.
--
-- Dates are plain tables in the user's local wall time. Everything goes
-- through days-from-civil rather than os.time(table), so none of it depends on
-- whether the host reads that table as local time or as UTC.

export type Moment = {
  year: number,
  month: number,
  day: number,
  hour: number,
  min: number,
  sec: number,
}

-- Short names, for formatMoment().
local DAY_NAMES = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTH_NAMES = {
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}

local function daysFromCivil(y: number, m: number, d: number): number
  local yy = y
  if m <= 2 then yy -= 1 end
  local era = math.floor(yy / 400)
  local yoe = yy - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

local function civilFromDays(z: number): (number, number, number)
  local zz = z + 719468
  local era = math.floor(zz / 146097)
  local doe = zz - era * 146097
  local yoe = math.floor(
    (doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365
  )
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + 3
  if mp >= 10 then m = mp - 9 end
  if m <= 2 then y += 1 end
  return y, m, d
end

local function moment(y, m, d, hh, mm, ss): Moment
  return { year = y, month = m, day = d, hour = hh or 0, min = mm or 0, sec = ss or 0 }
end

local function copyMoment(m: Moment): Moment
  return moment(m.year, m.month, m.day, m.hour, m.min, m.sec)
end

local function momentDays(m: Moment): number
  return daysFromCivil(m.year, m.month, m.day)
end

local function momentMinutes(m: Moment): number
  return momentDays(m) * 1440 + m.hour * 60 + m.min
end

local function weekdayOf(m: Moment): number
  return (momentDays(m) + 4) % 7
end

local function daysInMonth(y: number, m: number): number
  local ny, nm = y, m + 1
  if nm > 12 then nm, ny = 1, y + 1 end
  return daysFromCivil(ny, nm, 1) - daysFromCivil(y, m, 1)
end

local function addDays(m: Moment, n: number): Moment
  local y, mo, d = civilFromDays(momentDays(m) + n)
  local r = copyMoment(m)
  r.year, r.month, r.day = y, mo, d
  return r
end

local function addMonths(m: Moment, n: number): Moment
  local total = m.year * 12 + (m.month - 1) + n
  local y = math.floor(total / 12)
  local mo = total - y * 12 + 1
  local r = copyMoment(m)
  r.year, r.month = y, mo
  local dim = daysInMonth(y, mo)
  if r.day > dim then r.day = dim end
  return r
end

local function addMinutes(m: Moment, n: number): Moment
  local total = m.hour * 60 + m.min + n
  local dayShift = math.floor(total / 1440)
  local rem = total - dayShift * 1440
  local r = addDays(m, dayShift)
  r.hour = math.floor(rem / 60)
  r.min = rem % 60
  return r
end

local function isBefore(a: Moment, b: Moment): boolean
  local ma, mb = momentMinutes(a), momentMinutes(b)
  if ma ~= mb then return ma < mb end
  return a.sec < b.sec
end

local function sameDayOrLater(a: Moment, b: Moment): boolean
  return momentDays(a) >= momentDays(b)
end

-- The next `wd` weekday on or after `m`.
local function nextWeekday(m: Moment, wd: number): Moment
  return addDays(m, (wd - weekdayOf(m)) % 7)
end

-- The next day on or after `m` whose weekday is in `set`.
local function nextWeekdayIn(m: Moment, set: { [number]: boolean }): Moment
  for i = 0, 6 do
    local cand = addDays(m, i)
    if set[weekdayOf(cand)] then return cand end
  end
  return m
end

-- `dayNum` may be -1 for "last day of the month".
local function nextMonthDay(now: Moment, dayNum: number): Moment
  for i = 0, 12 do
    local head = addMonths(moment(now.year, now.month, 1), i)
    local dim = daysInMonth(head.year, head.month)
    local d = dayNum
    if d == -1 then d = dim end
    if d <= dim then
      local cand = moment(head.year, head.month, d)
      if sameDayOrLater(cand, now) then return cand end
    end
  end
  return moment(now.year, now.month, 1)
end

local function nextYearDay(now: Moment, month: number, day: number): Moment
  local cand = moment(now.year, month, math.min(day, daysInMonth(now.year, month)))
  if not sameDayOrLater(cand, now) then
    cand = moment(now.year + 1, month, math.min(day, daysInMonth(now.year + 1, month)))
  end
  return cand
end

local function nowMoment(): Moment
  local t = os.date("*t")
  return moment(t.year, t.month, t.day, t.hour, t.min, t.sec)
end

-- Local UTC offset, derived from the two os.date() views so we never depend on
-- whether the host's os.time(table) reads local or UTC.
local function tzOffsetMinutes(): number
  local l, u = os.date("*t"), os.date("!*t")
  local lm = daysFromCivil(l.year, l.month, l.day) * 1440 + l.hour * 60 + l.min
  local um = daysFromCivil(u.year, u.month, u.day) * 1440 + u.hour * 60 + u.min
  return lm - um
end

-- "2026-03-06T21:00:00+0100", the shape TickTick's OpenAPI wants.
local function momentToIso(m: Moment): string
  local off = tzOffsetMinutes()
  local sign = "+"
  if off < 0 then
    sign = "-"
    off = -off
  end
  return string.format(
    "%04d-%02d-%02dT%02d:%02d:%02d%s%02d%02d",
    m.year, m.month, m.day, m.hour, m.min, m.sec,
    sign, math.floor(off / 60), off % 60
  )
end

local function formatMoment(m: Moment, allDay: boolean?): string
  local out = string.format("%s %d %s %d", DAY_NAMES[weekdayOf(m) + 1], m.day, MONTH_NAMES[m.month], m.year)
  if not allDay then
    local hour, suffix = m.hour, "am"
    if hour >= 12 then suffix = "pm" end
    if hour == 0 then hour = 12 elseif hour > 12 then hour -= 12 end
    out ..= string.format(" %d:%02d%s", hour, m.min, suffix)
  end
  return out
end

return {
  moment = moment,
  copyMoment = copyMoment,
  momentDays = momentDays,
  momentMinutes = momentMinutes,
  weekdayOf = weekdayOf,
  daysInMonth = daysInMonth,
  addDays = addDays,
  addMonths = addMonths,
  addMinutes = addMinutes,
  isBefore = isBefore,
  sameDayOrLater = sameDayOrLater,
  nextWeekday = nextWeekday,
  nextWeekdayIn = nextWeekdayIn,
  nextMonthDay = nextMonthDay,
  nextYearDay = nextYearDay,
  nowMoment = nowMoment,
  momentToIso = momentToIso, -- "2026-03-06T21:00:00+0100", for the OpenAPI call
  formatMoment = formatMoment, -- "Fri 6 Mar 2026 9:00pm", for the launcher
}
