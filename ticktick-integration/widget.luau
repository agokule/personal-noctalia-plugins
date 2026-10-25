local local_types = require("./utils/types.luau")
local state = require('./utils/state.luau')
local api_types = require("./api/types.luau")
local api = require('./api/requests.luau')
local colors = require("./utils/color.luau")

local glyph_finished_task = "square-check"
local glyph_unfinished_task = "square"

local completed = false
local completed_time = 0

local max_delta_t = 2000

local task_to_show: api_types.Task

local function reset_from_comppleted()
  barWidget.setColor("on_surface")
  barWidget.setGlyphColor("on_surface")
  barWidget.setGlyph(glyph_unfinished_task)
end

function update()
  local data: local_types.PluginData = state.pluginData()

  if #data.overdue_tasks > 0 then
    task_to_show = data.overdue_tasks[1]
  else
    task_to_show = data.today_tasks[1]
  end

  if not completed then
    noctalia.setUpdateInterval(1000)
    barWidget.setGlyph(glyph_unfinished_task)
    barWidget.setText(task_to_show.title)
    return
  end

  local now = noctalia.nowMs()
  noctalia.setUpdateInterval(5)
  local delta_t = now - completed_time

  if delta_t > max_delta_t then
    api.complete_tasks(
      {
        projectId = task_to_show.projectId,
        taskIds = { task_to_show.id or '' }
      },
      function(res: HttpResponse)
        if res.status < 200 or res.status >= 300 then
          noctalia.notifyError("Ticktick complete task failed: " .. res.status, res.body)
          return
        end

        completed = false
        completed_time = 0
        noctalia.state.set('should_update', true)
      end
    )
    reset_from_comppleted()
  else
    local alpha = (math.sin(delta_t / (max_delta_t / 8)) + 2) * 255 / 3
    local color = colors.rgbToHex(148, 255, 243, alpha)
    barWidget.setColor(color)
    barWidget.setGlyphColor(color)
  end
end

function onClick()
  -- user canceled
  if completed then
    reset_from_comppleted()
    completed_time = 0
    completed = false
  else
    completed_time = noctalia.nowMs()
    completed = true
    barWidget.setGlyph(glyph_finished_task)
    noctalia.setUpdateInterval(5)
  end
end

