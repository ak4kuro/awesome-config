-----------------------------------------------------------------------------------------------------------------------
--                                               RedFlat network widget                                              --
-----------------------------------------------------------------------------------------------------------------------
-- Network speed monitoring widget
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local beautiful = require("beautiful")
local timer = require("gears.timer")

local redutil = require("redflat.util")
local monitor = require("redflat.gauge.icon.double")
local circle_gauge = require("redflat.gauge.monitor.circle")
local audio_gauge = require("redflat.gauge.audio.blue")
local tooltip = require("redflat.float.tooltip")
local system = require("redflat.system")
local tr = require("redflat.util.lang").t

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local net = { mt = {} }

local default_args = {
	speed     = { up = 10*1024, down = 10*1024 },
	autoscale = true,
	interface = "eth0",
	-- Con gauge circular: "up" / "down" = un solo anillo por sentido; nil = max(up,down) en un solo widget.
	direction = nil,
}

local function resolve_interface(args)
	if args.interface == "auto" then
		return system.default_net_interface()
	end
	return args.interface
end

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		widget    = monitor.new,
		monitor   = {},
		timeout   = 5,
		digits    = 2
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.net") or {})
end

-- Create a new network widget
-- @param args.timeout Update interval
-- @param args.interface Network interface
-- @param args.autoscale Scale bars, true by default
-- @param args.speed.up Max upload speed in bytes
-- @param args.speed.down Max download speed in bytes
-- @param style Settings for doublebar widget
-----------------------------------------------------------------------------------------------------------------------
function net.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local storage = {}
	local unit = {{  "B", 1 }, { "KB", 1024 }, { "MB", 1024^2 }, { "GB", 1024^3 }}
	args = redutil.table.merge(default_args, args or {})
	style = redutil.table.merge(default_style(), style or {})

	-- Create monitor widget
	--------------------------------------------------------------------------------
	local widg = style.widget(style.monitor)
	if type(widg.set_alert) ~= "function" then
		function widg:set_alert() end
	end

	-- Set tooltip
	--------------------------------------------------------------------------------
	local tp = tooltip({ objects = { widg } }, style.tooltip)

	-- Set update timer
	--------------------------------------------------------------------------------
	local t = timer({ timeout = style.timeout })
	t:connect_signal("timeout",
		function()
			local iface = resolve_interface(args)
			local state = system.net_speed(iface, storage)

			if args.autoscale then
				if state[1] > args.speed.up then args.speed.up = state[1] end
				if state[2] > args.speed.down then args.speed.down = state[2] end
			end

			local su, sd = args.speed.up, args.speed.down
			local ratio_up = su > 0 and (state[1] / su) or 0
			local ratio_down = sd > 0 and (state[2] / sd) or 0

			if args.alert then
				if args.direction == "up" then
					widg:set_alert(state[1] > args.alert.up)
				elseif args.direction == "down" then
					widg:set_alert(state[2] > args.alert.down)
				else
					widg:set_alert(state[1] > args.alert.up or state[2] > args.alert.down)
				end
			elseif args.alert_ratio and su > 0 and sd > 0 then
				if args.direction == "up" then
					widg:set_alert(ratio_up >= args.alert_ratio)
				elseif args.direction == "down" then
					widg:set_alert(ratio_down >= args.alert_ratio)
				else
					widg:set_alert(ratio_up >= args.alert_ratio or ratio_down >= args.alert_ratio)
				end
			end

			if style.widget == circle_gauge or style.widget == audio_gauge then
				if args.direction == "up" then
					widg:set_value(ratio_up)
				elseif args.direction == "down" then
					widg:set_value(ratio_down)
				else
					widg:set_value(math.max(ratio_down, ratio_up))
				end
			else
				widg:set_value({ ratio_down, ratio_up })
			end
			local label = iface
			if args.interface == "auto" then
				local kind = tr("Network")
				if iface:match("^wl") then
					kind = tr("Wi‑Fi")
				elseif iface:match("^eth") or iface:match("^en") or iface:match("^eno") then
					kind = tr("Wired")
				end
				label = iface .. " (" .. kind .. ")"
			end
			local tip
			if args.direction == "up" then
				tip = label .. "\n▴ " .. redutil.text.dformat(state[1], unit, style.digits, " ") .. " (" .. tr("upload") .. ")"
			elseif args.direction == "down" then
				tip = label .. "\n▾ " .. redutil.text.dformat(state[2], unit, style.digits, " ") .. " (" .. tr("download") .. ")"
			else
				tip = label .. "\n▾ " .. redutil.text.dformat(state[2], unit, style.digits, " ")
					.. "  ▴ " .. redutil.text.dformat(state[1], unit, style.digits, " ")
			end
			tp:set_text(tip)
		end
	)
	t:start()
	t:emit_signal("timeout")

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call net module as function
-----------------------------------------------------------------------------------------------------------------------
function net.mt:__call(...)
	return net.new(...)
end

return setmetatable(net, net.mt)
