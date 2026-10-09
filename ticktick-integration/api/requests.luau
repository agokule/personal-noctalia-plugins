local BASE_URL = 'https://api.ticktick.com'

local M = {}

local types = require("./types.luau")

function M.get_projects(cb: ({types.TicktickProject}) -> ())
  noctalia.http(
    {
      url = BASE_URL .. '/open/v1/project',
      headers = {
        "Authorization: Bearer " .. noctalia.getConfig("api_key")
      }
    },
    function(res: HttpResponse)
      if not res.ok then
        noctalia.notifyError("response not ok", res.body)
        return
      end

      local projects = noctalia.json.decode(res.body)
      cb(projects)
    end
  )
end

function M.create_task(task: types.TicktickTask, cb: (HttpResponse) -> ())
  noctalia.http(
    {
      url = BASE_URL .. '/open/v1/task',
      method = "POST",
      headers = {
        "Authorization: Bearer " .. noctalia.getConfig("api_key"),
        "Content-Type: application/json"
      },
      body = noctalia.json.encode(task, false)
    },
    function(res: HttpResponse)
      if not res.ok then
        noctalia.notifyError("Ticktick API response not ok", res.body)
      end

      cb(res)
    end
  )
end

return M

