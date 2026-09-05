--!nonstrict

function onQuery(text: string)
  local priority = nil

  launcher.setResults(text, {
    { id = text, title = text, subtitle = text }
  })
end

function onActivate(id)
  noctalia.notify("New Task", id)
end
