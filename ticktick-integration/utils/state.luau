local internal_types = require("./types.luau")

local M = {}

-- The service publishes `data` once its first fetch lands; until then there are
-- no lists to match, so ~list markers stay unresolved and tasks go to the inbox.
M.pluginData = function(): internal_types.PluginData
  return noctalia.state.get('data') or { projects = {}, project_names = {}, today_tasks = {}, overdue_tasks = {} }
end

return M

