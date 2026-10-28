-----------------------------------------------------------------------------------------------------------------------
--                                   RedFlat panel brightness widget (retroiluminación)                              --
-----------------------------------------------------------------------------------------------------------------------

local math = math
local tonumber = tonumber
local setmetatable = setmetatable

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local tooltip = require("redflat.float.tooltip")
local redutil = require("redflat.util")
local tr = require("redflat.util.lang").t

local backlight = { mt = {} }

-- Mismos patrones que Jiyu/keys-config.lua (brightness_control)
-- Filtrar por clase backlight real; fallback a xrandr si no hay hardware
local INCREASE = [[bash -lc 'step=%s; [ "$step" -lt 1 ] && step=1; ok=0; if command -v brightnessctl >/dev/null 2>&1 && brightnessctl -c backlight set "${step}%%+" >/dev/null 2>&1; then ok=1; fi; if [ "$ok" -ne 1 ]; then d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); pct=$(( (cur*100 + max/2) / max )); npct=$((pct + step)); [ "$npct" -gt 100 ] && npct=100; new=$(( (npct*max + 50) / 100 )); [ "$new" -gt "$max" ] && new=$max; echo "$new" > "$d/brightness" 2>/dev/null; echo $npct; exit 0; fi; fi; if [ "$ok" -ne 1 ]; then cur=$(xrandr --verbose 2>/dev/null | grep -m1 "Brightness:" | awk "{print \$2}"); cur=${cur:-1.0}; npct=$(awk "BEGIN{v=$cur+($step/100); if(v>1.0)v=1.0; printf \"%%d\", v*100}"); for o in $(xrandr --query 2>/dev/null | grep " connected" | awk "{print \$1}"); do xrandr --output "$o" --brightness "$(awk "BEGIN{print $cur+($step/100)}")" 2>/dev/null; done; echo $npct; exit 0; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); [ -z "$d" ] && echo 0 && exit 0; max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); echo $(( (cur*100 + max/2) / max ))']]

local DECREASE = [[bash -lc 'step=%s; [ "$step" -lt 1 ] && step=1; ok=0; if command -v brightnessctl >/dev/null 2>&1 && brightnessctl -c backlight set "${step}%%-" >/dev/null 2>&1; then ok=1; fi; if [ "$ok" -ne 1 ]; then d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); pct=$(( (cur*100 + max/2) / max )); npct=$((pct - step)); [ "$npct" -lt 0 ] && npct=0; new=$(( (npct*max + 50) / 100 )); [ "$new" -lt 0 ] && new=0; echo "$new" > "$d/brightness" 2>/dev/null; echo $npct; exit 0; fi; fi; if [ "$ok" -ne 1 ]; then cur=$(xrandr --verbose 2>/dev/null | grep -m1 "Brightness:" | awk "{print \$2}"); cur=${cur:-1.0}; npct=$(awk "BEGIN{v=$cur-($step/100); if(v<0.1)v=0.1; printf \"%%d\", v*100}"); for o in $(xrandr --query 2>/dev/null | grep " connected" | awk "{print \$1}"); do xrandr --output "$o" --brightness "$(awk "BEGIN{print $cur-($step/100)}")" 2>/dev/null; done; echo $npct; exit 0; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); [ -z "$d" ] && echo 0 && exit 0; max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); echo $(( (cur*100 + max/2) / max ))']]

local READ_PCT = [[bash -lc 'if command -v brightnessctl >/dev/null 2>&1; then c=$(brightnessctl -c backlight get 2>/dev/null); m=$(brightnessctl -c backlight max 2>/dev/null); if [ -n "$m" ] && [ "$m" -gt 0 ]; then echo $((c*100/m)); exit 0; fi; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); echo $(( (cur*100 + max/2) / max )); exit 0; fi; cur=$(xrandr --verbose 2>/dev/null | grep -m1 "Brightness:" | awk "{print \$2}"); if [ -n "$cur" ]; then echo $(awk "BEGIN{printf \"%d\", $cur*100}"); exit 0; fi; echo NO_DEVICE']]

local function default_style()
	local style = {
		notify      = {},
		widget      = require("redflat.gauge.audio.blue").new,
		audio       = {},
		tooltip     = {},
		step        = 5,
		timeout     = 5,
		labels      = { no_device = tr("No backlight device") },
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.backlight") or {})
end

local function parse_pct_line(out)
	if not out then
		return nil
	end
	local line = out:match("^%s*(.-)%s*$") or ""
	if line == "NO_DEVICE" then
		return nil
	end
	local n = tonumber(line:match("^(%d+)"))
	return n
end

-- read.output() usa assert(io.popen): en algunos sistemas falla y tumba el callback del widget / el panel.
local function read_pct_output()
	local ok, out = pcall(redutil.read.output, READ_PCT)
	if not ok then
		return nil
	end
	return out
end

function backlight:update_brightness()
	local out = read_pct_output()
	local pct = parse_pct_line(out)
	if pct == nil then
		self:set_value(0)
		self:set_mute(true)
		self._tooltip:set_text(self._style.labels.no_device)
		return
	end
	pct = math.min(100, math.max(0, pct))
	self:set_mute(false)
	self:set_value(pct / 100)
	self._tooltip:set_text(pct .. "%")
end

-- Tras bajar el brillo, sysfs/brightnessctl a veces devuelve el valor antiguo unos ms;
-- un par de relecturas diferidas alinean el gauge con el hardware.
local function schedule_brightness_resync(widg, extra_delays)
	if not extra_delays then
		return
	end
	for _, sec in ipairs(extra_delays) do
		gears.timer.start_new(sec, function()
			pcall(function()
				widg:update_brightness()
			end)
		end)
	end
end

function backlight:change_brightness(args)
	args = args or {}
	local step = args.step or self._step or 5
	local down = args.down
	local cmd = string.format(down and DECREASE or INCREASE, step)
	awful.spawn.easy_async_with_shell(cmd, function(o)
		pcall(function()
			local pct = parse_pct_line(o)
			if pct ~= nil then
				pct = math.min(100, math.max(0, pct))
				self:set_value(pct / 100)
				self:set_mute(false)
				self._tooltip:set_text(pct .. "%")
			else
				self:update_brightness()
			end
		end)
		-- Re-sincronizar pronto (sobre todo al bajar: sysfs/brightnessctl puede ir unos ms detrás del echo del script)
		local delays = { 0.06, 0.18 }
		if down then
			delays[#delays + 1] = 0.35
			delays[#delays + 1] = 0.6
		end
		schedule_brightness_resync(self, delays)
	end)
end

function backlight.new(args, style)
	args = args or {}
	style = redutil.table.merge(default_style(), style or {})

	local widg = style.widget(style.audio)
	-- No usar gears.table.crush con el módulo entero: copia `mt` y `new` al wibox y puede romper el dibujo.
	widg.update_brightness = backlight.update_brightness
	widg.change_brightness = backlight.change_brightness

	widg._style = style
	widg._step = args.step or style.step or 5

	widg._tooltip = tooltip({ objects = { widg } }, style.tooltip)

	local timeout = args.timeout or style.timeout or 5
	if args.autoupdate ~= false then
		local t = gears.timer({ timeout = timeout })
		t:connect_signal("timeout", function()
			pcall(function()
				widg:update_brightness()
			end)
		end)
		t:start()
	end

	gears.timer.delayed_call(function()
		pcall(function()
			widg:update_brightness()
		end)
	end)

	return widg
end

function backlight.mt:__call(...)
	return backlight.new(...)
end

return setmetatable(backlight, backlight.mt)
