--!nonstrict
-- One chip per populated Umbriel scratchpad; a click toggles it. The sizes and
-- colors match jamesfeeder/special-workspaces, which draws Hyprland's chips in the
-- same spot, so the bar looks the same under both compositors.

local STATE_KEY = "scratchpads"

local function toggle(name)
  -- Nothing to refresh on success: the new state arrives on the service's stream.
  noctalia.runAsync({ "umbriel", "msg", "scratchpad-toggle", name }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log(`Umbriel scratchpads: toggling {name} failed: {result.stderr}`)
    end
  end)
end

local function render(scratchpads)
  local chips = {}
  for _, scratchpad in ipairs(scratchpads) do
    local name = scratchpad.name
    table.insert(
      chips,
      ui.row({
        key = name,
        align = "center",
        justify = "center",
        fill = scratchpad.active and "primary" or "secondary",
        radius = 8,
        height = 16,
        minWidth = 35,
        paddingH = 5,
        tooltip = table.concat(scratchpad.titles, "\n"),
        onClick = function()
          toggle(name)
        end,
      }, {
        ui.label({
          text = name,
          fontSize = 11,
          color = scratchpad.active and "on_primary" or "on_secondary",
          textAlign = "center",
        }),
      })
    )
  end

  barWidget.setVisible(#chips > 0)
  barWidget.render(ui.row({ gap = 4, align = "center" }, chips))
end

noctalia.state.watch(STATE_KEY, function(value)
  render(type(value) == "table" and value or {})
end)

render(noctalia.state.get(STATE_KEY) or {})
