local api_types = require("../api/types.luau")

export type PluginData = {
  projects: {api_types.Project},
  project_names: {string},
}

return {}

