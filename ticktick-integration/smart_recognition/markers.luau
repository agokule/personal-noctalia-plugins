--!nonstrict
-- The quick-add markers TickTick's help page does not document:
--
--   !<priority>  none | low | medium | high (also n/l/m/h and 0/1/2/3)
--   #<tag>       one word of letters, digits, "-", "_" and non-ASCII
--   ~<list>      or ^<list>; quote it (~"My List") when the name has spaces
--
-- Only the first priority and the first list marker count; every tag does.

local Scanner = require("./scanner.luau")
local Vocabulary = require("./vocabulary.luau")

local function extractPriority(state, out)
  local at = 1
  while true do
    local s, e, word = string.find(state.lower, "!(%w+)", at)
    if not s then return end
    local before = ""
    if s > 1 then before = string.sub(state.lower, s - 1, s - 1) end
    local after = ""
    if e < #state.lower then after = string.sub(state.lower, e + 1, e + 1) end
    local name = Vocabulary.PRIORITY_WORDS[word]
    if name and not string.match(before, "%w") and not string.match(after, "%w") then
      out.priorityName = name
      out.priority = Vocabulary.PRIORITY_VALUES[name]
      Scanner.record(state, "priority", s, e)
      return
    end
    at = s + 1
  end
end

local function extractTags(state, out)
  local at = 1
  while true do
    local s, e, tag = string.find(state.lower, "#([%w_%-\128-\255]+)", at)
    if not s then return end
    local before = ""
    if s > 1 then before = string.sub(state.lower, s - 1, s - 1) end
    if not string.match(before, "[%w#]") then
      table.insert(out.tags, string.sub(state.text, s + 1, e))
      Scanner.record(state, "tag", s, e)
    end
    at = e + 1
  end
end

local function normalizeName(s: string): string
  return (string.gsub(string.lower(s), "[^%w]", ""))
end

local function isSubsequence(needle: string, hay: string): boolean
  local i = 1
  for c in string.gmatch(hay, ".") do
    if i > #needle then break end
    if c == string.sub(needle, i, i) then i += 1 end
  end
  return i > #needle
end

-- Best fuzzy match for what the user typed after ~ / ^, or nil if nothing is close.
local function matchList(query: string, lists): string?
  if not lists or not query or query == "" then return nil end
  local q = normalizeName(query)
  if q == "" then return nil end
  local best, bestScore = nil, 0
  for _, name in ipairs(lists) do
    local n = normalizeName(name)
    local score = 0
    if n ~= "" then
      local coverage = #q / #n * 10
      local initials = ""
      for word in string.gmatch(string.lower(name), "%a+") do
        initials ..= string.sub(word, 1, 1)
      end
      if n == q then
        score = 100
      elseif string.sub(n, 1, #q) == q then
        score = 80 + coverage
      elseif string.find(n, q, 1, true) then
        score = 60 + coverage
      elseif initials == q then
        score = 55
      elseif #q > 1 and isSubsequence(q, n) then
        score = 30 + coverage
      end
    end
    if score > bestScore then
      best, bestScore = name, score
    end
  end
  return best
end

local function extractList(state, out, lists)
  local s, e, nameStart, nameEnd
  s, e = string.find(state.lower, '[~%^]"[^"]+"')
  if s then
    nameStart, nameEnd = s + 2, e - 1
  else
    s, e = string.find(state.lower, "[~%^][%w_%-\128-\255]+")
    if not s then return end
    nameStart, nameEnd = s + 1, e
  end
  local before = ""
  if s > 1 then before = string.sub(state.lower, s - 1, s - 1) end
  if string.match(before, "%w") then return end -- e.g. "3^2"
  out.listQuery = string.sub(state.text, nameStart, nameEnd)
  out.list = matchList(out.listQuery, lists)
  Scanner.record(state, "list", s, e)
end

-- Fills in priority, tags, list and listQuery on `out`.
local function extract(state, out, lists: { string }?)
  extractPriority(state, out)
  extractTags(state, out)
  extractList(state, out, lists)
end

return {
  extract = extract,
  matchList = matchList, -- exported for callers that fetch list names later
}
