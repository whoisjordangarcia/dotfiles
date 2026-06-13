local settings = require("settings")

local icons = {
  sf_symbols = {
    plus = "􀅼",
    loading = "􀖇",
    apple = "􀣺",
    gear = "􀍟",
    cpu = "􀫥",
    clipboard = "􀉄",

    switch = {
      on = "􁏮",
      off = "􁏯",
    },
    volume = {
      _100="􀊩",
      _66="􀊧",
      _33="􀊥",
      _10="􀊡",
      _0="􀊣",
    },
    battery = {
      _100 = "􀛨",
      _75 = "􀺸",
      _50 = "􀺶",
      _25 = "􀛩",
      _0 = "􀛪",
      charging = "􀢋"
    },
    wifi = {
      upload = "􀄨",
      download = "􀄩",
      connected = "􀙇",
      disconnected = "􀙈",
      router = "􁓤",
      -- SF Symbols has no per-strength wifi glyphs; reuse the base icon
      signal = {
        _0 = "􀙈",
        _1 = "􀙇",
        _2 = "􀙇",
        _3 = "􀙇",
        _4 = "􀙇",
      },
    },
    media = {
      back = "􀊊",
      forward = "􀊌",
      play_pause = "􀊈",
    },
  },

  -- Alternative NerdFont icons
  nerdfont = {
    plus = "",
    loading = "",
    apple = "",
    gear = "",
    cpu = "",
    clipboard = "Missing Icon",

    switch = {
      on = "󱨥",
      off = "󱨦",
    },
    volume = {
      _100="",
      _66="",
      _33="",
      _10="",
      _0="",
    },
    battery = {
      _100 = "",
      _75 = "",
      _50 = "",
      _25 = "",
      _0 = "",
      charging = ""
    },
    wifi = {
      upload = "",
      download = "",
      connected = "󰖩",
      disconnected = "󰖪",
      router = "󱇢",
      signal = {
        _0 = "󰤯",
        _1 = "󰤟",
        _2 = "󰤢",
        _3 = "󰤥",
        _4 = "󰤨",
      },
    },
    media = {
      back = "",
      forward = "",
      play_pause = "",
    },
  },
}

if not (settings.icons == "NerdFont") then
  return icons.sf_symbols
else
  return icons.nerdfont
end
