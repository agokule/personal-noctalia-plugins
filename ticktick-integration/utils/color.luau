--!nonstrict

local M = {}

-- One 0–255 channel as two hex digits. Out-of-range and fractional values are
-- clamped and rounded rather than producing a malformed color.
local function channel(v: number): string
  return string.format("%02x", math.clamp(math.round(v), 0, 255))
end

-- "#rrggbb", or "#rrggbbaa" when an alpha is given: the hex forms UiColor and
-- barWidget.setColor accept. Every channel, alpha included, is 0–255.
M.rgbToHex = function(r: number, g: number, b: number, a: number?): string
  local hex = "#" .. channel(r) .. channel(g) .. channel(b)
  if a ~= nil then
    hex ..= channel(a)
  end
  return hex
end

return M
