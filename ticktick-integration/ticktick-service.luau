local ticktick = require('./api/requests.luau')
local types = require('./utils/types.luau')
local api_types = require('./api/types.luau')

-- update every 5 minutes for now
noctalia.setUpdateInterval(5 * 1000 * 60)

local started = false

function update()
  if not started then
    started = true
    local default_plugin_data: types.TicktickPluginData = {
      projects = {},
      project_names = {},
    }
    noctalia.state.set('data', default_plugin_data)
  end

  ticktick.get_projects(function (projects: {api_types.TicktickProject})
    local data: types.TicktickPluginData = noctalia.state.get("data")
    data.projects = projects

    local project_names: {string} = {}
    for index, proj: api_types.TicktickProject in ipairs(projects) do
      table.insert(project_names, proj.name)
    end
    data.project_names = project_names

    noctalia.state.set('data', data)
  end)
end

