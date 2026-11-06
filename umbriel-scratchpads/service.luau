--!nonstrict
-- Publishes Umbriel's populated scratchpads for the bar widget.
--
-- Noctalia's taskbar can't show these: its Umbriel backend drops every window
-- without a workspace, and scratchpad windows have none. `umbriel subscribe`
-- does report their scratchpad, so this service reads that stream instead. Under
-- any other compositor the socket is missing and nothing is published.

local STATE_KEY = "scratchpads"
local RECONNECT_INTERVAL_MS = 1000
-- runStream has no exit callback, so the end of the stream is reported on stdout.
local DISCONNECTED_MARKER = "__UMBRIEL_SCRATCHPADS_DISCONNECTED__"
local STREAM_COMMAND = "umbriel subscribe windows; printf '\\n" .. DISCONNECTED_MARKER .. "\\n'"

local streaming = false
local lastPublished = nil

-- ── snapshot ─────────────────────────────────────────────────────────────────

local function publish(windows)
  local scratchpads = {}
  local byName = {}
  for _, window in ipairs(windows) do
    local name = window.scratchpad
    if type(name) == "string" and name ~= "" then
      local scratchpad = byName[name]
      if scratchpad == nil then
        scratchpad = { name = name, active = false, titles = {} }
        byName[name] = scratchpad
        table.insert(scratchpads, scratchpad)
      end
      scratchpad.active = scratchpad.active or window.visible == true
      table.insert(scratchpad.titles, window.title)
    end
  end
  table.sort(scratchpads, function(a, b)
    return a.name < b.name
  end)

  -- The stream repeats the whole window list on any change to any window.
  local encoded = noctalia.json.encode(scratchpads)
  if encoded ~= lastPublished then
    lastPublished = encoded
    noctalia.state.set(STATE_KEY, scratchpads)
  end
end

-- ── stream ───────────────────────────────────────────────────────────────────

-- A shell started by systemd can inherit WAYLAND_DISPLAY without UMBRIEL_SOCKET.
-- This follows the CLI's fallback, as noctalia/umbriel-companion does.
local function socketPath()
  local explicit = noctalia.getenv("UMBRIEL_SOCKET")
  if explicit ~= nil and explicit ~= "" then
    return explicit
  end
  local runtimeDir = noctalia.getenv("XDG_RUNTIME_DIR")
  local display = noctalia.getenv("WAYLAND_DISPLAY")
  if runtimeDir ~= nil and runtimeDir ~= "" and display ~= nil and display ~= "" then
    return `{runtimeDir}/umbriel-{display}.sock`
  end
  return nil
end

local function onLine(line)
  if line == DISCONNECTED_MARKER then
    streaming = false
    publish({})
    return
  end
  local message = noctalia.json.decode(line)
  if type(message) == "table" and message.event == "windows" and type(message.data) == "table" then
    publish(message.data)
  end
end

local function startStream()
  if streaming then
    return
  end
  local path = socketPath()
  if path == nil or not noctalia.fileExists(path) or not noctalia.commandExists("umbriel") then
    return
  end
  streaming = noctalia.runStream(STREAM_COMMAND, onLine)
end

function update()
  startStream()
end

noctalia.setUpdateInterval(RECONNECT_INTERVAL_MS)
startStream()
