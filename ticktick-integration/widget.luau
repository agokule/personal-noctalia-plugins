function update()
  noctalia.setUpdateInterval(2000)
  barWidget.setGlyph("checkbox")
end

function onClick()
  noctalia.notify("hello", "testing")
end

