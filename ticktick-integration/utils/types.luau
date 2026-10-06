local api_types = require("../api/types.luau")

export type TicktickPluginData = {
  projects: {api_types.TicktickProject},
  project_names: {string},
}

return {}

