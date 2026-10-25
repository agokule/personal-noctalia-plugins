--!nonstrict
-- Launcher entry: parses the typed text with TickTick's Smart Recognition
-- rules and previews the task it would create. See smart_recognition/init.luau for
-- the syntax it understands.

local SmartRecognition = require("./smart_recognition/init.luau")
local internal_types = require('./utils/types.luau')
local state = require("./utils/state.luau")
local api = require('./api/requests.luau')
local convert = require('./api/convert.luau')

function onQuery(text: string)
  if text == "" then
    launcher.setResults(text, {})
    return
  end

  local plugin_data: internal_types.PluginData = state.pluginData()
  local parsed = SmartRecognition.parseTask(text, plugin_data.project_names)

  local title = parsed.title
  if title == "" then title = text end
  launcher.setResults(text, {
    { id = text, title = title, subtitle = SmartRecognition.describeTask(parsed), glyph = "circle-plus" },
  })
end

function onActivate(id: string)
  local plugin_data: internal_types.PluginData = state.pluginData()
  local parsed = SmartRecognition.parseTask(id, plugin_data.project_names)

  api.create_task(convert.toTask(parsed, plugin_data.projects),
    function (res: HttpResponse)
      local title = parsed.title
      if title == "" then title = id end

      if api.is_success(res) then
        noctalia.notify("New Task", title .. "\n" .. SmartRecognition.describeTask(parsed))
        noctalia.state.set('should_update', true)
      end
    end
  )
end
