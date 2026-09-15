-- Run: lua scale_test.lua
package.path = (arg[0]:match("^(.*)/") or ".") .. "/?.lua;" .. package.path

local n = 0
local function check(desc, ok)
	n = n + 1
	print((ok and "✓ " or "✗ ") .. desc)
	if not ok then
		os.exit(1)
	end
end

local scale = require("scale")
scale.scale = 2

local out = scale.scale_props({
	height = 30,
	border_width = 1,
	width = "dynamic",
	label = { font = { family = "GohuFont", size = 13.0 }, padding_left = -5 },
})

check("scales geometry", out.height == 60)
check("scales nested font size", out.label.font.size == 26)
check("scales negative padding", out.label.padding_left == -10)
check("leaves border_width alone", out.border_width == 1)
check("leaves non-numbers alone", out.width == "dynamic")
check("preserves untouched values", out.label.font.family == "GohuFont")

-- The reason scale_props copies: sbar.set re-sends the same props each tick.
local props = { height = 30 }
scale.scale_props(props)
scale.scale_props(props)
check("does not mutate its input", props.height == 30)

local calls = {}
local fake = {}
for _, name in ipairs({ "bar", "default", "add", "set" }) do
	fake[name] = function(...)
		calls[name] = table.pack(...)
		return "item"
	end
end
scale.install(fake)

check("add: passes through non-table args", fake.add("item", "foo", { height = 20 }) == "item")
check("add: name arg untouched", calls.add[2] == "foo")
check("add: props scaled", calls.add[3].height == 40)
check("add: arity preserved", calls.add.n == 3)
fake.bar({ height = 30 })
check("bar: props scaled", calls.bar[1].height == 60)

print(("All %d tests passed"):format(n))
