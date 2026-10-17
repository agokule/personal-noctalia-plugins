local types = require("./types.luau")

local M = {}

-- The service publishes `data` once its first fetch lands; until then there are
-- no lists to match, so ~list markers stay unresolved and tasks go to the inbox.
M.pluginData = function(): types.TicktickPluginData
  return noctalia.state.get('data') or { projects = {}, project_names = {} }
end

return M

