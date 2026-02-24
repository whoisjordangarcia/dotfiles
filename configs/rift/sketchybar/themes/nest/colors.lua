-- Catppuccin Mocha palette
return {
  black = 0xff11111b,
  white = 0xffcdd6f4,
  red = 0xfff38ba8,
  green = 0xffa6e3a1,
  blue = 0xff89b4fa,
  yellow = 0xfff9e2af,
  orange = 0xfffab387,
  magenta = 0xffcba6f7,
  teal = 0xff94e2d5,
  pink = 0xfff5c2e7,
  grey = 0xff6c7086,
  subtle = 0xff45475a,
  text = 0xffcdd6f4,
  subtext = 0xffa6adc8,
  overlay = 0xff585b70,
  surface2 = 0xff585b70,
  surface1 = 0xff45475a,
  surface0 = 0xff313244,
  base = 0xff1e1e2e,
  mantle = 0xff181825,
  crust = 0xff11111b,
  transparent = 0x00000000,

  bar = {
    bg = 0xd0181825,
    border = 0x00000000,
  },
  popup = {
    bg = 0xd0181825,
    border = 0xff45475a,
  },
  bg1 = 0x40585b70,
  bg2 = 0x30585b70,

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
