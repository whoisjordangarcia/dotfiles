-- Catppuccin Latte palette
return {
  black = 0xffdce0e8,
  white = 0xff4c4f69,
  red = 0xffd20f39,
  green = 0xff40a02b,
  blue = 0xff1e66f5,
  yellow = 0xffdf8e1d,
  orange = 0xfffe640b,
  magenta = 0xff8839ef,
  teal = 0xff179299,
  pink = 0xffea76cb,
  grey = 0xff9ca0b0,
  subtle = 0xffbcc0cc,
  text = 0xff4c4f69,
  subtext = 0xff6c6f85,
  overlay = 0xffacb0be,
  surface2 = 0xffacb0be,
  surface1 = 0xffbcc0cc,
  surface0 = 0xffccd0da,
  base = 0xffeff1f5,
  mantle = 0xffe6e9ef,
  crust = 0xffdce0e8,
  transparent = 0x00000000,

  bar = {
    bg = 0xffe6e9ef,
    border = 0x20000000,
  },
  popup = {
    bg = 0xd0e6e9ef,
    border = 0xffbcc0cc,
  },
  bg1 = 0x40acb0be,
  bg2 = 0x30acb0be,

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
