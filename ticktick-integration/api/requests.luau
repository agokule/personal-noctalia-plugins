local BASE_URL = 'https://api.ticktick.com'

local M = {}

local types = require("./types.luau")

-- res.ok only means the request reached the server: a 401 or a 500 still has
-- it set, so success also needs a 2xx status.
function M.is_success(res: HttpResponse): boolean
  return res.ok and res.status >= 200 and res.status < 300
end

function M.get_projects(cb: ({types.TicktickProject}) -> ())
  noctalia.http(
    {
      url = BASE_URL .. '/open/v1/project',
      headers = {
        "Authorization: Bearer " .. noctalia.getConfig("api_key")
      }
    },
    function(res: HttpResponse)
      if not M.is_success(res) then
        noctalia.notifyError("response not ok", `HTTP {res.status}: {res.body}`)
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
      if not M.is_success(res) then
        noctalia.notifyError("Ticktick API response not ok", `HTTP {res.status}: {res.body}`)
      end

      cb(res)
    end
  )
end

return M

