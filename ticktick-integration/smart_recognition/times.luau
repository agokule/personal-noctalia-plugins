--!nonstrict
-- Time recognition: "9am", "9 am", "09:00", "at 9", "noon", "morning", and
-- the ranges "9am - 10am" / "9am to 10am".
--
-- A match sets plan.hour and plan.min, plus plan.endHour/plan.endMin for a
-- range. A bare "at 9" is marked ambiguous so the resolver can pick whichever
-- of 9:00 and 21:00 comes first.

local Scanner = require("./scanner.luau")
local Vocabulary = require("./vocabulary.luau")

local WORD_TIMES = {
  morning = { 9, 0 }, noon = { 12, 0 }, midday = { 12, 0 },
  afternoon = { 13, 0 }, evening = { 17, 0 }, midnight = { 0, 0 },
}

-- Returns s, e, hour, min, meridiem ("a"/"p"/nil), ambiguous
local function findTimeToken(lower: string, init: number?)
  local best = nil
  local function offer(s, e, hour, min, merid, ambiguous)
    if hour == nil or hour > 23 or min > 59 then return end
    if not best or s < best[1] or (s == best[1] and e > best[2]) then
      best = { s, e, hour, min, merid, ambiguous }
    end
  end
  local function glued(s)
    local before = ""
    if s > 1 then before = string.sub(lower, s - 1, s - 1) end
    return before == ":" or before == "/"
  end
  local function to24(h, merid)
    if merid == "a" then
      if h == 12 then return 0 end
      return h
    end
    if h < 12 then return h + 12 end
    return h
  end

  local s, e, hh, mm, merid = Scanner.findWord(lower, "(%d%d?):(%d%d)%s*([ap])%.?m%.?", init)
  if s and not glued(s) then offer(s, e, to24(tonumber(hh), merid), tonumber(mm), merid, false) end

  s, e, hh, merid = Scanner.findWord(lower, "(%d%d?)%s*([ap])%.?m%.?", init)
  if s and not glued(s) then offer(s, e, to24(tonumber(hh), merid), 0, merid, false) end

  s, e, hh, mm = Scanner.findWord(lower, "(%d%d?):(%d%d):%d%d", init)
  if s and not glued(s) then offer(s, e, tonumber(hh), tonumber(mm), nil, false) end

  s, e, hh, mm = Scanner.findWord(lower, "(%d%d?):(%d%d)", init)
  if s and not glued(s) then offer(s, e, tonumber(hh), tonumber(mm), nil, false) end

  for word, t in pairs(WORD_TIMES) do
    s, e = Scanner.findWord(lower, word, init)
    if s then offer(s, e, t[1], t[2], nil, false) end
  end

  -- A bare hour only counts when introduced: "at 9", "@ 9".
  s, e, hh = Scanner.findWord(lower, "at%s+(%d%d?)", init)
  if s then
    local after = ""
    if e < #lower then after = string.sub(lower, e + 1, e + 1) end
    if not string.match(after, "[:%d]") and not string.find(lower, "^%s*[ap]%.?m", e + 1) then
      offer(s, e, tonumber(hh), 0, nil, true)
    end
  end

  if not best then return nil end
  return best[1], best[2], best[3], best[4], best[5], best[6]
end

local function extractTime(state, plan)
  local s1, e1, h1, m1, merid1, ambiguous = findTimeToken(state.lower)
  if not s1 then return false end

  -- range: "9am - 10am", "9am to 10am"
  local rest = string.sub(state.lower, e1 + 1)
  local _, connEnd = string.find(rest, "^%s*%-%s*")
  if not connEnd then _, connEnd = string.find(rest, "^%s+to%s+") end
  if not connEnd then _, connEnd = string.find(rest, "^%s+until%s+") end
  if connEnd then
    local s2, e2, h2, m2, merid2 = findTimeToken(state.lower, e1 + 1)
    if s2 == e1 + connEnd + 1 then
      if not merid1 and merid2 == "p" and h1 < 12 then h1 += 12 end
      plan.hour, plan.min = h1, m1
      plan.endHour, plan.endMin = h2, m2
      Scanner.record(state, "time", Scanner.extendLeft(state, s1, Vocabulary.TIME_PREFIXES), e2)
      return true
    end
  end

  plan.hour, plan.min, plan.ambiguousHour = h1, m1, ambiguous
  Scanner.record(state, "time", Scanner.extendLeft(state, s1, Vocabulary.TIME_PREFIXES), e1)
  return true
end

return { extract = extractTime }
