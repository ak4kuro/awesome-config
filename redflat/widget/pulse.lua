-----------------------------------------------------------------------------------------------------------------------
--                                   RedFlat pulseaudio volume control widget                                        --
-----------------------------------------------------------------------------------------------------------------------
-- Indicate and change volume level using pacmd or pactl (PipeWire / sin paquete pulseaudio)
-----------------------------------------------------------------------------------------------------------------------
-- Some code was taken from
------ Pulseaudio volume control
------ https://github.com/orofarne/pulseaudio-awesome/blob/master/pulseaudio.lua
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local math = math
local table = table
local tonumber = tonumber
local string = string
local setmetatable = setmetatable
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")

local tooltip = require("redflat.float.tooltip")
local audio = require("redflat.gauge.audio.blue")
local rednotify = require("redflat.float.notify")
local redutil = require("redflat.util")
local tr = require("redflat.util.lang").t

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local pulse = { widgets = {}, mt = {} }
pulse.startup_time = 4

do
	local function path_cmd(cmd)
		local f = io.popen("command -v " .. cmd .. " 2>/dev/null")
		if not f then
			return nil
		end
		local p = f:read("*l")
		f:close()
		return p and p ~= "" and p or nil
	end
	-- pactl primero: PipeWire/pulseaudio suele tener ambos; @DEFAULT_SINK@ y lecturas son más fiables que pacmd.
	if path_cmd("pactl") then
		pulse._backend = "pactl"
	elseif path_cmd("pacmd") then
		pulse._backend = "pacmd"
	else
		pulse._backend = nil
	end
end

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		notify      = {},
		widget      = audio.new,
		audio       = {}
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.pulse") or {})
end

local change_volume_default_args = {
	down        = false,
	step        = math.floor(65536 / 100 * 5 + 0.5),
	show_notify = false
}

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function pactl_trim_first_line(cmd)
	local line = redutil.read.output(cmd)
	if not line then
		return nil
	end
	return line:match("^%s*(.-)%s*$")
end

-- PipeWire a veces deja el default en analógico; el BT suele estar IDLE (conectado) y solo RUNNING al reproducir.
local function pactl_active_bluez_sink_name()
	local out = redutil.read.output("LC_ALL=C pactl list sinks 2>/dev/null")
	if not out then
		return nil
	end
	local name, state = nil, nil
	local function try_flush()
		if name and state and state ~= "SUSPENDED" and name:find("bluez", 1, true) and not name:find("%.monitor$") then
			return name
		end
		return nil
	end
	for line in out:gmatch("[^\r\n]+") do
		if line:match("^Sink #") then
			local hit = try_flush()
			if hit then
				return hit
			end
			name, state = nil, nil
		end
		local nm = line:match("^%s*Name:%s*(%S+)")
		if nm then
			name = nm
		end
		local st = line:match("^%s*State:%s*(%S+)")
		if st then
			state = st
		end
	end
	return try_flush()
end

local function get_default_sink(args)
	args = args or {}
	local type_ = args.type or "sink"

	if pulse._backend == "pactl" then
		if type_ == "sink" then
			local def = pactl_trim_first_line("LC_ALL=C pactl get-default-sink 2>/dev/null")
			if not def or def == "" then
				return "@DEFAULT_SINK@"
			end
			if not def:find("bluez", 1, true) then
				local bt = pactl_active_bluez_sink_name()
				if bt then
					return bt
				end
			end
			return def
		end
		local defs = pactl_trim_first_line("LC_ALL=C pactl get-default-source 2>/dev/null")
		if defs and defs ~= "" then
			return defs
		end
		return "@DEFAULT_SOURCE@"
	end

	if pulse._backend ~= "pacmd" then
		return nil
	end

	local cmd = string.format("pacmd dump | grep 'set-default-%s'", type_)
	local output = redutil.read.output(cmd)
	local def_sink = string.match(output, "set%-default%-%w+%s(.+)\r?\n")

	return def_sink
end

-- Change volume level
-----------------------------------------------------------------------------------------------------------------------
function pulse:change_volume(args)

	-- initialize vars
	args = redutil.table.merge(change_volume_default_args, args or {})
	local diff = args.down and -args.step or args.step

	if pulse._backend == "pactl" then
		local step_pct = math.max(1, math.floor(math.abs(diff) / 65536 * 100 + 0.5))
		local sign = args.down and "-" or "+"
		local show_notify = args.show_notify
		local cmd = string.format(
			"LC_ALL=C pactl set-%s-volume %s %s%d%%",
			self._type,
			self._sink,
			sign,
			step_pct
		)
		awful.spawn.easy_async_with_shell(cmd, function()
			self:update_volume()
			if show_notify and self._last_vol_pct then
				local v = self._last_vol_pct
				rednotify:show(
					redutil.table.merge({ value = v / 100, text = string.format("%.0f", v) .. "%" }, self._style.notify)
				)
			end
		end)
		return
	end

	if pulse._backend ~= "pacmd" then
		return
	end

	-- get current volume
	local v = redutil.read.output(string.format("pacmd dump | grep 'set-%s-volume %s'", self._type, self._sink))
	local parsed = string.match(v, "0x%x+")

	-- catch possible problems with pacmd output
	if not parsed then
		naughty.notify({ title = tr("Warning!"), text = tr("PA widget can't parse pacmd output") })
		return
	end

	local volume = tonumber(parsed)

	-- calculate new volume
	local new_volume = volume + diff

	if new_volume > 65536 then
		new_volume = 65536
	elseif new_volume < 0 then
		new_volume = 0
	end

	-- show notify if need
	if args.show_notify then
		local vol = new_volume / 65536
		rednotify:show(
			redutil.table.merge({ value = vol, text = string.format('%.0f', vol*100) .. "%" }, self._style.notify)
		)
	end

	-- set new volume
	awful.spawn(string.format("pacmd set-%s-volume %s %s", self._type, self._sink, new_volume))

	-- update volume indicators
	self:update_volume()
end

-- Set mute
-----------------------------------------------------------------------------------------------------------------------
function pulse:mute()
	if not self._type or not self._sink then
		return
	end

	if pulse._backend == "pactl" then
		local cmd = string.format("LC_ALL=C pactl set-%s-mute %s toggle", self._type, self._sink)
		awful.spawn.easy_async_with_shell(cmd, function()
			self:update_volume()
		end)
		return
	end

	if pulse._backend ~= "pacmd" then
		return
	end

	local mute = redutil.read.output(string.format("pacmd dump | grep 'set-%s-mute %s'", self._type, self._sink))

	if string.find(mute, "no", -4) then
		awful.spawn(string.format("pacmd set-%s-mute %s yes", self._type, self._sink))
	else
		awful.spawn(string.format("pacmd set-%s-mute %s no", self._type, self._sink))
	end

	self:update_volume()
end

-- Update volume level info
-----------------------------------------------------------------------------------------------------------------------
function pulse:update_volume(args)
	args = args or {}
	-- Sin sink/source fijo en rc: seguir el dispositivo por defecto (p. ej. al pasar de altavoz a Bluetooth).
	if self._follow_default and self._type then
		local s = get_default_sink({ type = self._type })
		if s then
			self._sink = s
		end
	end
	if not self._type or not self._sink then
		return
	end

	if pulse._backend == "pactl" then
		local v = redutil.read.output(string.format("LC_ALL=C pactl get-%s-volume %s", self._type, self._sink))
		local m = redutil.read.output(string.format("LC_ALL=C pactl get-%s-mute %s", self._type, self._sink))
		local volume = 0
		if v then
			local pct = string.match(v, "/%s+(%d+)%%")
			if not pct then
				pct = string.match(v, "(%d+)%%")
			end
			if pct then
				volume = tonumber(pct) or 0
			end
		end
		local mute = m and string.match(m, "Mute:%s+yes") ~= nil
		self._last_vol_pct = volume
		self:set_value(volume / 100)
		self:set_mute(mute)
		local tip = volume .. "%"
		if self._type == "sink" and self._sink and self._sink:find("bluez", 1, true) then
			tip = tip .. " (BT)"
		end
		self._tooltip:set_text(tip)
		return
	end

	if pulse._backend ~= "pacmd" then
		return
	end

	-- initialize vars
	local volmax = 65536
	local volume = 0

	-- get current volume and mute state
	local v = redutil.read.output(string.format("pacmd dump | grep 'set-%s-volume %s'", self._type, self._sink))
	local m = redutil.read.output(string.format("pacmd dump | grep 'set-%s-mute %s'", self._type, self._sink))

	if v then
		local pv = string.match(v, "0x%x+")
		if pv then volume = math.floor(tonumber(pv) * 100 / volmax + 0.5) end
	end

	local mute = not (m and string.find(m, "no", -4))

	self._last_vol_pct = volume
	-- update widgets value
	self:set_value(volume / 100)
	self:set_mute(mute)
	self._tooltip:set_text(volume .. "%")
end

-- Create a new pulse widget
-- @param timeout Update interval
-----------------------------------------------------------------------------------------------------------------------
function pulse.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	style = redutil.table.merge(default_style(), style or {})

	args = args or {}
	local timeout = args.timeout or 5
	local autoupdate = args.autoupdate or false

	-- create widget
	--------------------------------------------------------------------------------
	local widg = style.widget(style.audio)
	gears.table.crush(widg, pulse, true) -- dangerous since widget have own methods, but let it be by now

	widg._type = args.type or "sink"
	widg._sink = args.sink
	widg._follow_default = args.sink == nil
	widg._style = style

	table.insert(pulse.widgets, widg)

	-- Set tooltip
	--------------------------------------------------------------------------------
	widg._tooltip = tooltip({ objects = { widg } }, style.tooltip)

	-- Set update timer
	--------------------------------------------------------------------------------
	if autoupdate then
		local t = gears.timer({ timeout = timeout })
		t:connect_signal("timeout", function() widg:update_volume() end)
		t:start()
	end

	-- Set startup timer
	-- This is workaround if module activated bofore pulseaudio servise start
	--------------------------------------------------------------------------------
	if not widg._sink then
		local st = gears.timer({ timeout = 1 })
		local counter = 0
		st:connect_signal("timeout", function()
			counter = counter + 1
			widg._sink = get_default_sink({ type = widg._type })
			if widg._sink then widg:update_volume() end
			if counter > pulse.startup_time or widg._sink then st:stop() end
		end)
		st:start()
	else
		widg:update_volume()
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call pulse module as function
-----------------------------------------------------------------------------------------------------------------------
function pulse.mt:__call(...)
	return pulse.new(...)
end

return setmetatable(pulse, pulse.mt)
