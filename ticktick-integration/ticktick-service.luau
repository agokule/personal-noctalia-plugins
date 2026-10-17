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

-- Today at the given local wall time.
local function today_at(hour: number, min: number, sec: number): Calendar.Moment
  local now = Calendar.nowMoment()
  return Calendar.moment(now.year, now.month, now.day, hour, min, sec)
end

-- When a task happens, as seconds since the epoch: its start, else its due
-- date. A task with neither sorts after every timed one.
local function task_time(api_task: api_types.Task): number
  local iso = api_task.startDate or api_task.dueDate
  return iso and Calendar.isoToEpoch(iso) or math.huge
end

-- The local day a task happens on, as days since the epoch.
local function task_day(api_task: api_types.Task): number
  return (task_time(api_task) + Calendar.tzOffsetMinutes() * 60) // 86400
end

-- The order a list of tasks is shown in: day by day, and within a day all-day
-- tasks first, the way a calendar's all-day row sits above its hours, then
-- timed ones from earliest to latest. Ties go to the higher priority, then to
-- TickTick's manual order (lower sortOrder first), then to the id, so the order
-- can't shuffle between refreshes.
local function comes_before(a: api_types.Task, b: api_types.Task): boolean
  local a_day, b_day = task_day(a), task_day(b)
  if a_day ~= b_day then return a_day < b_day end

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
  local api_body: api_types.UndoneTasksBody = {
    startDate = Calendar.momentToIso(today_at(0, 0, 0)),
    endDate = Calendar.momentToIso(today_at(23, 59, 59)),
  }

  ticktick.get_undone_tasks(api_body, function (api_tasks: {api_types.Task})
    table.sort(api_tasks, comes_before)

    local plugin_data: internal_types.PluginData = state.pluginData()
    plugin_data.today_tasks = api_tasks
    noctalia.state.set('data', plugin_data)
  end)
end

-- Whether a task ended before `midnight` (seconds since the epoch). A multi-day
-- all-day task's dueDate is the midnight after its last day, so it has ended
-- once that midnight has passed; any other task ends at its due date, or at its
-- start if it has none.
local function ended_before(api_task: api_types.Task, midnight: number): boolean
  local start = api_task.startDate and Calendar.isoToEpoch(api_task.startDate)
  local due = api_task.dueDate and Calendar.isoToEpoch(api_task.dueDate)
  if api_task.isAllDay and start and due and due > start then
    return due <= midnight
  end

  local last = due or start
  return last ~= nil and last < midnight
end

-- Fetches the undone tasks that ended before today and publishes them sorted.
-- /task/filter only bounds startDate, so it also returns tasks that started
-- before today but are still running; ended_before drops those. It returns at
-- most 200 tasks.
local function refresh_overdue_tasks()
  local api_body: api_types.FilterTasksBody = {
    endDate = Calendar.momentToIso(Calendar.addDays(today_at(23, 59, 59), -1)),
    status = { 0 },
  }
  local midnight = Calendar.isoToEpoch(Calendar.momentToIso(today_at(0, 0, 0)))

  ticktick.filter_tasks(api_body, function (api_tasks: {api_types.Task})
    local api_overdue_tasks: {api_types.Task} = {}
    for _, api_task in ipairs(api_tasks) do
      if ended_before(api_task, midnight) then
        table.insert(api_overdue_tasks, api_task)
      end
    end
    table.sort(api_overdue_tasks, comes_before)

    local plugin_data: internal_types.PluginData = state.pluginData()
    plugin_data.overdue_tasks = api_overdue_tasks
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
      overdue_tasks = {},
    }
    noctalia.state.set('data', default_plugin_data)
  end

  refresh_projects()
  refresh_today_tasks()
  refresh_overdue_tasks()
end

