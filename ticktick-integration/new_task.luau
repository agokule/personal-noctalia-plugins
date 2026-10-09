--!nonstrict
-- Launcher entry: parses the typed text with TickTick's Smart Recognition
-- rules and previews the task it would create. See smart_recognition/init.luau for
-- the syntax it understands.

local SmartRecognition = require("./smart_recognition/init.luau")
local types = require('./utils/types.luau')
local api = require('./api/requests.luau')
local convert = require('./api/convert.luau')

-- The service publishes `data` once its first fetch lands; until then there are
-- no lists to match, so ~list markers stay unresolved and tasks go to the inbox.
local function pluginData(): types.TicktickPluginData
  return noctalia.state.get('data') or { projects = {}, project_names = {} }
end

function onQuery(text: string)
  if text == "" then
    launcher.setResults(text, {})
    return
  end

  local data: types.TicktickPluginData = pluginData()
  local task = SmartRecognition.parseTask(text, data.project_names)

  local title = task.title
  if title == "" then title = text end
  launcher.setResults(text, {
    { id = text, title = title, subtitle = SmartRecognition.describeTask(task), glyph = "circle-plus" },
  })
end

function onActivate(id: string)
  local data: types.TicktickPluginData = pluginData()
  local task = SmartRecognition.parseTask(id, data.project_names)

  api.create_task(convert.toTicktickTask(task, data.projects),
    function (res: HttpResponse)
      local title = task.title
      if title == "" then title = id end

      if api.is_success(res) then
        noctalia.notify("New Task", title .. "\n" .. SmartRecognition.describeTask(task))
      end
    end
  )
end
