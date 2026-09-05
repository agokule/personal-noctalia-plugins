--!nonstrict
-- The working text every extractor shares.
--
-- Recognising a token means blanking its span out of both the original-case
-- and the lowercased copy. Blanks are spaces of the same width, so indices
-- stay valid across extractors and whatever is left is the task title.

export type Match = { kind: string, text: string }

export type State = {
  text: string, -- the input, with recognised spans blanked out
  lower: string, -- the same string lowercased, what patterns run against
  matches: { Match },
}

local function new(text: string): State
  return { text = text, lower = string.lower(text), matches = {} }
end

-- string.find, but the match must not be glued to surrounding alphanumerics.
local function findWord(hay: string, pat: string, init: number?)
  local at = init or 1
  while true do
    local res = { string.find(hay, pat, at) }
    local s, e = res[1], res[2]
    if not s then return nil end
    local before, after = "", ""
    if s > 1 then before = string.sub(hay, s - 1, s - 1) end
    if e < #hay then after = string.sub(hay, e + 1, e + 1) end
    if not string.match(before, "%w") and not string.match(after, "%w") then
      return table.unpack(res)
    end
    at = s + 1
  end
end

-- Blanks a span out of the working strings (same length, so indices stay valid)
-- and remembers what was there.
local function record(state, kind: string, s: number, e: number)
  local text = string.gsub(string.sub(state.text, s, e), "^%s*(.-)%s*$", "%1")
  table.insert(state.matches, { kind = kind, text = text })
  local blank = string.rep(" ", e - s + 1)
  state.text = string.sub(state.text, 1, s - 1) .. blank .. string.sub(state.text, e + 1)
  state.lower = string.sub(state.lower, 1, s - 1) .. blank .. string.sub(state.lower, e + 1)
end

-- Swallows a leading filler word ("at 9am" -> also eat the "at").
local function extendLeft(state, s: number, words): number
  local prefix = string.sub(state.lower, 1, s - 1)
  local pos, word = string.match(prefix, "()(%a+)%s*$")
  if pos and words[word] then return pos end
  return s
end

-- Tries each rule in order; a rule's fn returns true once it has consumed.
local function scanRules(state, rules, ctx): boolean
  for _, rule in ipairs(rules) do
    local at = 1
    while true do
      local res = { findWord(state.lower, rule.pat, at) }
      local s = res[1]
      if not s then break end
      if rule.fn(state, ctx, s, res[2], res[3], res[4], res[5]) then return true end
      at = s + 1
    end
  end
  return false
end

local function cleanTitle(text: string): string
  local title = string.gsub(text, "%s+", " ")
  title = string.gsub(title, "%s+([,;:%.])", "%1")
  title = string.gsub(title, ",%s*,", ",")
  title = string.gsub(title, "^[%s,;:%-]+", "")
  title = string.gsub(title, "[%s,;:%-]+$", "")
  return title
end

return {
  new = new,
  findWord = findWord,
  record = record,
  extendLeft = extendLeft,
  scanRules = scanRules,
  cleanTitle = cleanTitle,
}
