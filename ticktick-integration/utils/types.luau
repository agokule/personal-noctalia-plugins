local api_types = require("../api/types.luau")

export type PluginData = {
  projects: {api_types.Project},
  project_names: {string},
  -- Today's undone tasks in display order: all-day ones first, then by time
  -- (see ticktick-service.luau).
  today_tasks: {api_types.Task},
}

return {}

