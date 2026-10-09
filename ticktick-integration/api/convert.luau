--!nonstrict
-- Conversions between the parser's ParsedTask and the Open API's Task body.

local SmartRecognition = require("../smart_recognition/init.luau")
local types = require("./types.luau")

local M = {}

-- ── ParsedTask → Task ───

-- The Open API's alias for the user's inbox, which GET /open/v1/project does
-- not list.
local INBOX_ID = "inbox"

-- Finds the id of the project the parser matched by name, or the inbox.
local function projectIdFor(name: string?, projects: {types.TicktickProject}): string
  if name then
    for _, project in ipairs(projects) do
      if project.name == name then return project.id end
    end
  end
  return INBOX_ID
end

-- Empty arrays are left out rather than sent, so the encoder never has to guess
-- whether an empty table is a JSON array or an object.
local function nonEmpty(list: {string}): {string}?
  if #list == 0 then return nil end
  return list
end

--[[
  Builds the body for POST /open/v1/task from a parsed quick-add string.

    task      the ParsedTask from SmartRecognition.parseTask
    projects  the cached project list, to resolve `task.list` to an id

  A task with no ~list, or one that matched nothing, goes to the inbox, since
  projectId is required. A title the parser emptied entirely ("tomorrow 9am")
  falls back to the raw input, since title is required too.
]]
function M.toTicktickTask(task: SmartRecognition.ParsedTask, projects: {types.TicktickProject}): types.TicktickTask
  local title = task.title
  if title == "" then title = task.raw end

  local out: types.TicktickTask = {
    title = title,
    projectId = projectIdFor(task.list, projects),
    priority = task.priority,
    tags = nonEmpty(task.tags),
    repeatFlag = task.repeatFlag,
    reminders = nonEmpty(task.reminders),
  }

  if task.dueDate then
    out.isAllDay = task.isAllDay
    out.dueDate = SmartRecognition.momentToIso(task.dueDate)
  end
  if task.startDate then
    out.startDate = SmartRecognition.momentToIso(task.startDate)
  end

  return out
end

return M
