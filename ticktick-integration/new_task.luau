--!nonstrict
-- Launcher entry: parses the typed text with TickTick's Smart Recognition
-- rules and previews the task it would create. See smart_recognition/init.luau for
-- the syntax it understands.

local SmartRecognition = require("./smart_recognition/init.luau")

function onQuery(text: string)
  if text == "" then
    launcher.setResults(text, {})
    return
  end
  local task = SmartRecognition.parseTask(text)
  local title = task.title
  if title == "" then title = text end
  launcher.setResults(text, {
    { id = text, title = title, subtitle = SmartRecognition.describeTask(task), icon = "circle-plus" },
  })
end

function onActivate(id: string)
  local task = SmartRecognition.parseTask(id)
  local title = task.title
  if title == "" then title = id end
  noctalia.notify("New Task", title .. "\n" .. SmartRecognition.describeTask(task))
end
