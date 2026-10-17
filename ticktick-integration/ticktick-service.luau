local ticktick = require('./api/requests.luau')
local internal_types = require('./utils/types.luau')
local state = require("./utils/state.luau")
local api_types = require('./api/types.luau')

-- update every 5 minutes for now
noctalia.setUpdateInterval(5 * 1000 * 60)

local started = false

function update()
  if not started then
    started = true
    local default_plugin_data: internal_types.PluginData = {
      projects = {},
      project_names = {},
    }
    noctalia.state.set('data', default_plugin_data)
  end

  ticktick.get_projects(function (api_projects: {api_types.Project})
    local plugin_data: internal_types.PluginData = state.pluginData()
    plugin_data.projects = api_projects

    local project_names: {string} = {}
    for index, api_project: api_types.Project in ipairs(api_projects) do
      table.insert(project_names, api_project.name)
    end
    plugin_data.project_names = project_names

    noctalia.state.set('data', plugin_data)
  end)
end

