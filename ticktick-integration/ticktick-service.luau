local ticktick = require('./api/requests.luau')
local internal_types = require('./utils/types.luau')
local state = require("./utils/state.luau")
local api_types = require('./api/types.luau')
local Calendar = require('./smart_recognition/calendar.luau')

-- update every 5 minutes for now
noctalia.setUpdateInterval(5 * 1000 * 60)

local started = false

local function refresh_projects()
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

-- When a task happens, as seconds since the epoch: its start, else its due
-- date. A task with neither sorts after every timed one.
local function task_time(api_task: api_types.Task): number
  local iso = api_task.startDate or api_task.dueDate
  return iso and Calendar.isoToEpoch(iso) or math.huge
end

-- The order today's tasks are shown in: all-day tasks first, the way a
-- calendar's all-day row sits above its hours, then timed ones from earliest to
-- latest. Ties go to the higher priority, then to TickTick's manual order
-- (lower sortOrder first), then to the id, so the order can't shuffle between
-- refreshes.
local function comes_before(a: api_types.Task, b: api_types.Task): boolean
  local a_all_day, b_all_day = a.isAllDay == true, b.isAllDay == true
  if a_all_day ~= b_all_day then return a_all_day end
  if not a_all_day then
    local a_time, b_time = task_time(a), task_time(b)
    if a_time ~= b_time then return a_time < b_time end
  end

  local a_priority, b_priority = a.priority or 0, b.priority or 0
  if a_priority ~= b_priority then return a_priority > b_priority end

  local a_order, b_order = a.sortOrder or 0, b.sortOrder or 0
  if a_order ~= b_order then return a_order < b_order end

  return (a.id or "") < (b.id or "")
end

-- Fetches the undone tasks dated today, local time, and publishes them sorted.
local function refresh_today_tasks()
  local now = Calendar.nowMoment()
  local api_body: api_types.UndoneTasksBody = {
    startDate = Calendar.momentToIso(Calendar.moment(now.year, now.month, now.day, 0, 0, 0)),
    endDate = Calendar.momentToIso(Calendar.moment(now.year, now.month, now.day, 23, 59, 59)),
  }

  ticktick.get_undone_tasks(api_body, function (api_tasks: {api_types.Task})
    table.sort(api_tasks, comes_before)

    local plugin_data: internal_types.PluginData = state.pluginData()
    plugin_data.today_tasks = api_tasks
    noctalia.state.set('data', plugin_data)
  end)
end

function update()
  if not started then
    started = true
    local default_plugin_data: internal_types.PluginData = {
      projects = {},
      project_names = {},
      today_tasks = {},
    }
    noctalia.state.set('data', default_plugin_data)
  end

  refresh_projects()
  refresh_today_tasks()
end

