--!nonstrict
-- Conversions between the parser's ParsedTask and the Open API's Task body.

local SmartRecognition = require("../smart_recognition/init.luau")
local api_types = require("./types.luau")

local M = {}

-- ── ParsedTask → Task ───

-- The Open API's alias for the user's inbox, which GET /open/v1/project does
-- not list.
local INBOX_ID = "inbox"

-- Finds the id of the project the parser matched by name, or the inbox.
local function projectIdFor(name: string?, apiProjects: {api_types.Project}): string
  if name then
    for _, apiProject in ipairs(apiProjects) do
      if apiProject.name == name then return apiProject.id end
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

    parsed       the ParsedTask from SmartRecognition.parseTask
    apiProjects  the cached project list, to resolve `parsed.list` to an id

  A task with no ~list, or one that matched nothing, goes to the inbox, since
  projectId is required. A title the parser emptied entirely ("tomorrow 9am")
  falls back to the raw input, since title is required too.
]]
function M.toTask(parsed: SmartRecognition.ParsedTask, apiProjects: {api_types.Project}): api_types.Task
  local title = parsed.title
  if title == "" then title = parsed.raw end

  local apiTask: api_types.Task = {
    title = title,
    projectId = projectIdFor(parsed.list, apiProjects),
    priority = parsed.priority,
    tags = nonEmpty(parsed.tags),
    repeatFlag = parsed.repeatFlag,
    reminders = nonEmpty(parsed.reminders),
  }

  if parsed.dueDate then
    apiTask.isAllDay = parsed.isAllDay
    apiTask.dueDate = SmartRecognition.momentToIso(parsed.dueDate)
  end
  if parsed.startDate then
    apiTask.startDate = SmartRecognition.momentToIso(parsed.startDate)
  end

  return apiTask
end

return M
