-----------------------------------------------------------------------------------------------------------------------
--                                                   Jiyu config                                                     --
-----------------------------------------------------------------------------------------------------------------------

-- Load modules
-----------------------------------------------------------------------------------------------------------------------

-- Standard awesome library
------------------------------------------------------------
local awful = require("awful")
local tagutil = require("Jiyu.util-tag")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local gears = require("gears")
local L = require("Jiyu.locale").t

-- Cualquier código (incl. librerías) que llame awful.tag.viewtoggle(nil) rompe en tag.lua:1444.
do
	local _viewtoggle = awful.tag.viewtoggle
	function awful.tag.viewtoggle(t)
		if t == nil then
			return
		end
		local ok, err = pcall(_viewtoggle, t)
		if not ok then
			gears.debug.print_warning("viewtoggle: " .. tostring(err))
		end
	end
end

require("awful.autofocus")

-- debug locker (antes de redflat; el tema debe cargarse antes que cualquier submódulo use beautiful)
local lock = lock or {}

-- Quick toggles (set false to remove fast)
local SHOW_HOTKEYS_POPUP_ON_STARTUP = true

-- Tema: true = JiyuLight (blanco/azul), false = Jiyu (rojo/gris oscuro)
-- Se lee desde rc.lua (_G.JIYU_CONFIG), por defecto true si no está definido
local USE_LIGHT_THEME
if _G.JIYU_CONFIG and _G.JIYU_CONFIG.USE_LIGHT_THEME ~= nil then
	USE_LIGHT_THEME = _G.JIYU_CONFIG.USE_LIGHT_THEME
else
	USE_LIGHT_THEME = true
end

-- Tema y entorno primero: beautiful.init antes de require("redflat") evita orden raro si algo tocara el tema al cargar.
-----------------------------------------------------------------------------------------------------------------------
-- XKB: español + inglés US con Alt+Shift para cambiar (necesario para el widget kbindicator)
-- Se lanza aquí (no en autostart) para asegurar que los 2 grupos existen antes de crear el widget.
awful.spawn.with_shell('setxkbmap -query 2>/dev/null | grep -q "layout:.*es,us" || setxkbmap -layout es,us -option grp:alt_shift_toggle')

local env = require("Jiyu.env-config")
-- desktop_autohide=false: widgets del escritorio visibles con ventanas abiertas.
-- locale: "auto" (LANG → es*), o "es" / "en"
local UI_LANG = (_G.JIYU_CONFIG and _G.JIYU_CONFIG.UI_LANG) or "auto"
env:init({
	theme = USE_LIGHT_THEME and "JiyuLight" or "Jiyu",
	desktop_autohide = false,
	set_center = true,
	locale = UI_LANG
})

-- User modules (tras tema cargado)
------------------------------------------------------------
local redflat   = require("redflat")
local redutil   = require("redflat.util")
local redmenu   = require("redflat.menu")
local dock = require("Jiyu.dock")
local clipboard = require("Jiyu.clipboard")

redflat.startup.locked = lock.autostart

redflat.startup:activate()

-- Inicializar clipboard history
clipboard:init()


-- Error handling (después de env:init para que Jiyu.locale esté configurado)
-----------------------------------------------------------------------------------------------------------------------
require("Jiyu.ercheck-config") -- load file with error handling


-- Layouts setup
-----------------------------------------------------------------------------------------------------------------------
local layouts = require("Jiyu.layout-config") -- load file with tile layouts setup
layouts:init()


-- Main menu configuration
-----------------------------------------------------------------------------------------------------------------------
local mymenu = require("Jiyu.menu-config") -- load file with menu configuration
mymenu:init({ env = env })


-- Panel widgets
-----------------------------------------------------------------------------------------------------------------------

-- Separadores: una instancia por cada hueco (un widget no puede estar en varios padres).
--------------------------------------------------------------------------------
local function panel_separator()
	return redflat.gauge.separator.vertical()
end

-- Taglist widget
--------------------------------------------------------------------------------
local taglist = {}

taglist.style = { widget = redflat.gauge.tag.orange.new, show_tip = true }

-- double line taglist
-- Solo 6 escritorios virtuales (3x2)
taglist.cols_num = 6
taglist.rows_num = 1

taglist.layout = wibox.widget {
	expand          = true,
	forced_num_rows = taglist.rows_num,
	forced_num_cols = taglist.cols_num,
    layout          = wibox.layout.grid,
}

-- buttons
taglist.buttons = awful.util.table.join(
	awful.button({         }, 1, function(t) tagutil.view_only(t) end),
	awful.button({ env.mod }, 1, function(t) if t and client.focus then client.focus:move_to_tag(t) end end),
	awful.button({         }, 2, function(t) tagutil.viewtoggle(t) end),
	awful.button({         }, 3, function(t) if t then redflat.widget.layoutbox:toggle_menu(t) end end),
	awful.button({ env.mod }, 3, function(t) if t and client.focus then client.focus:toggle_tag(t) end end),
	awful.button({         }, 4, function(t) tagutil.viewnext_from_tag(t) end),
	awful.button({         }, 5, function(t) tagutil.viewprev_from_tag(t) end)
)

-- some tag settings which indirectly depend on row and columns number of taglist
-- Nombres de los escritorios virtuales (6 columnas del panel Jiyu)
taglist.names = { "1", "2", "3", "4", "5", "6" }

-- Layout por defecto al cargar: maximizado en mosaico (suit.max) en todos los tags
local max_layout = awful.layout.suit.max
taglist.layouts = {}
for i = 1, #taglist.names do
	taglist.layouts[i] = max_layout
end

-- Tasklist
--------------------------------------------------------------------------------
local tasklist = {}

-- dirty double tag line setup for tasklist client menu
local tagline_style = { tagline = { height = 40, rows = taglist.rows_num, spacing = 4 } }

-- load list of app name aliases from files and set it as part of tasklist theme
tasklist.style = {
	appnames = require("Jiyu.alias-config"),  widget = redflat.gauge.task.Jiyu.new,
	winmenu = tagline_style,
	color = { main = (beautiful.color and beautiful.color.main) or "#0066CC", icon = "#ffffff", gray = "#ffffff" },
}

tasklist.buttons = awful.util.table.join(
	awful.button({}, 1, redflat.widget.tasklist.action.select),
	awful.button({}, 2, redflat.widget.tasklist.action.close),
	awful.button({}, 3, redflat.widget.tasklist.action.menu),
	awful.button({}, 4, redflat.widget.tasklist.action.switch_next),
	awful.button({}, 5, redflat.widget.tasklist.action.switch_prev)
)

-- double tag line setup for main client menu
redflat.float.clientmenu:set_style(tagline_style)


-- Textclock widget
--------------------------------------------------------------------------------
local textclock = {}
local es_wday_short = { "do", "lu", "ma", "mi", "ju", "vi", "sá" }
local es_month_short = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" }
local function panel_date_localized()
	if env.locale == "es" then
		local d = os.date("*t")
		return string.format("%s  %02d  %s", es_month_short[d.month] or "", d.day, es_wday_short[d.wday] or "")
	end
	return os.date("%b  %d  %a")
end
textclock.widget = redflat.widget.textclock({
	timeformat = "%H:%M",
	dateformat = "%b  %d  %a",
	dateformat_fn = panel_date_localized,
})

textclock.buttons = awful.util.table.join(
	awful.button({}, 1, function() redflat.float.calendar:show() end)
)

-- Layoutbox configure
--------------------------------------------------------------------------------
local layoutbox = {}

layoutbox.buttons = awful.util.table.join(
	awful.button({ }, 3, function () mymenu.mainmenu:toggle() end),
	awful.button({ }, 1, function ()
		local s = awful.screen.focused()
		if s and s.selected_tag then
			redflat.widget.layoutbox:toggle_menu(s.selected_tag)
		end
	end),
	awful.button({ }, 4, function () awful.layout.inc( 1) end),
	awful.button({ }, 5, function () awful.layout.inc(-1) end)
)

-- Tray widget
--------------------------------------------------------------------------------
local tray = {}
tray.widget = redflat.widget.minitray()

tray.buttons = awful.util.table.join(
	awful.button({}, 1, function() redflat.widget.minitray:toggle() end)
)

-- PA volume control (solo icono; niveles en pulsectl con sliders por dispositivo)
--------------------------------------------------------------------------------
local volume = {}
do
	-- Icono volumen: rojo sube de abajo arriba al subir; al bajar se vacía de arriba abajo (franja anclada abajo).
	local va = redutil.table.merge(beautiful.gauge.audio.blue or {}, {
		gauge = false,
		width = 32,
		icon_fill_from_bottom = true,
		icon_mute_at_zero = true,
	})
	volume.widget = redflat.widget.pulse(
		{ autoupdate = true, timeout = 5 },
		{ widget = redflat.gauge.audio.blue.new, audio = va }
	)
end

-- activate player widget
redflat.float.player:init({ name = env.player })

-- Notificación OSD de volumen al cambiar (efímera, 1s)
-- Timer único reutilizado con again() + un solo shell que devuelve "VOL MUTE".
local volume_osd_timer = gears.timer({ timeout = 0.3, single_shot = true })
volume_osd_timer:connect_signal("timeout", function()
	awful.spawn.easy_async_with_shell(
		[[bash -c 'v=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP "\d+%" | head -1); m=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP "yes|no" | head -1); echo "${v:-?} ${m:-no}"']],
		function(out)
			local pct, mut = out and out:match("(%S+)%s+(%S+)")
			naughty.notify({
				title = L("Volume"),
				text = (mut == "yes") and ((pct or "?") .. " [MUTED]") or (pct or "?"),
				timeout = 1,
				font = "Lato 10",
				screen = awful.screen.focused(),
			})
		end
	)
end)
local function volume_osd()
	volume_osd_timer:again()
end

volume.buttons = awful.util.table.join(
	awful.button({}, 1, function() redflat.float.pulsectl.sinks:show() end),
	awful.button({}, 4, function() volume.widget:change_volume(); volume_osd() end),
	awful.button({}, 5, function() volume.widget:change_volume({ down = true }); volume_osd() end),
	awful.button({}, 2, function() volume.widget:mute(); volume_osd() end),
	awful.button({ "Control" }, 3, function() redflat.float.player:show()       end),
	awful.button({}, 8, function() redflat.float.player:action("Previous")      end),
	awful.button({}, 9, function() redflat.float.player:action("Next")          end)
)

-- Brillo de pantalla: solo icono (gauge = false); clic izquierdo → brightctl
--------------------------------------------------------------------------------
local backlight = {}
do
	-- Detectar si hay backlight hardware real
	local function has_hw_backlight()
		local f = io.popen("ls /sys/class/backlight/*/brightness 2>/dev/null | head -1")
		if not f then return false end
		local line = f:read("*l")
		f:close()
		return line ~= nil and line ~= ""
	end

	-- Crear el widget SIEMPRE con redflat.widget.backlight (mismo aspecto siempre)
	local audio = redutil.table.merge(beautiful.gauge.backlight.red or {}, {
		gauge = false,
		width = 32,
		icon_fill_from_bottom = true,
		icon_mute_at_zero = true,
	})
	local ok, w = pcall(function()
		return redflat.widget.backlight({ autoupdate = true, timeout = 3 }, { audio = audio })
	end)

	if ok and w then
		backlight.widget = w

		if not has_hw_backlight() then
			-- Sin backlight hardware: parchear el widget para usar xrandr
			local xrandr_val = 1.0
			local xrandr_step = 0.05

			local function get_xrandr_outputs()
				local outputs = {}
				local f = io.popen("xrandr --query 2>/dev/null | grep ' connected' | awk '{print $1}'")
				if f then
					for line in f:lines() do
						table.insert(outputs, line)
					end
					f:close()
				end
				return outputs
			end

			local function apply_xrandr(val)
				val = math.min(1.0, math.max(0.1, val))
				for _, out in ipairs(get_xrandr_outputs()) do
					awful.spawn(string.format("xrandr --output %s --brightness %.2f", out, val), false)
				end
			end

			-- Sobrescribir update_brightness: mostrar valor xrandr en el gauge
			w.update_brightness = function()
				xrandr_val = math.min(1.0, math.max(0.1, xrandr_val))
				w:set_value(xrandr_val)
				w:set_mute(false)
				if w._tooltip then
					w._tooltip:set_text(math.floor(xrandr_val * 100) .. "%")
				end
			end

			-- Sobrescribir change_brightness: subir/bajar con xrandr
			w.change_brightness = function(self, args)
				args = args or {}
				local down = args.down
				if down then
					xrandr_val = math.max(0.1, xrandr_val - xrandr_step)
				else
					xrandr_val = math.min(1.0, xrandr_val + xrandr_step)
				end
				apply_xrandr(xrandr_val)
				w:update_brightness()
			end
			-- Registrar callbacks para la barra flotante (brightctl)
			redflat.float.brightctl:set_brightness_callback(function(pct)
				xrandr_val = math.min(1.0, math.max(0.1, pct / 100))
				apply_xrandr(xrandr_val)
			end)
			redflat.float.brightctl:get_brightness_callback(function()
				return math.floor(xrandr_val * 100)
			end)

			-- Inicializar
			w:set_value(1.0)
			w:set_mute(false)
		end

		redflat.float.brightctl:set_panel_widget(w)
		backlight.buttons = awful.util.table.join(
			awful.button({}, 1, function() redflat.float.brightctl:show() end),
			awful.button({}, 4, function() backlight.widget:change_brightness() end),
			awful.button({}, 5, function() backlight.widget:change_brightness({ down = true }) end)
		)
	end
end

-- PA microphone
--------------------------------------------------------------------------------
local microphone = {}

-- tricky custom style (gauge = false: solo icono, sin barra dash)
local microphone_style = {
	widget = redflat.gauge.audio.blue.new,
	audio = redutil.table.merge(
		beautiful.individual and beautiful.individual.microphone_audio or {},
		{
			gauge = false,
			icon_fill_from_bottom = true,
			icon_mute_at_zero = true,
		}
	),
}
microphone_style.audio.gauge = false

-- init widget
microphone.widget = redflat.widget.pulse(
	{ type = "source", autoupdate = true, timeout = 5 },
	microphone_style
)

microphone.buttons = awful.util.table.join(
	awful.button({}, 1, function() redflat.float.pulsectl.sources:show() end),
	awful.button({}, 2, function() microphone.widget:mute() end),
	awful.button({}, 4, function() microphone.widget:change_volume() end),
	awful.button({}, 5, function() microphone.widget:change_volume({ down = true }) end)
)

-- Keyboard layout indicator
--------------------------------------------------------------------------------
local kbindicator = {}
redflat.widget.keyboard:init({ L("Spanish"), L("English") })
kbindicator.widget = redflat.widget.keyboard()

kbindicator.buttons = awful.util.table.join(
	awful.button({}, 1, function () redflat.widget.keyboard:toggle_menu() end),
	awful.button({}, 4, function () redflat.widget.keyboard:toggle()      end),
	awful.button({}, 5, function () redflat.widget.keyboard:toggle(true)  end)
)

-- Caps Lock indicator (texto "CAPS" en el panel cuando está activo)
--------------------------------------------------------------------------------
local capslock = {}
capslock.widget = wibox.widget.textbox("")
capslock.widget:set_font("Lato bold 9")
capslock.widget:set_markup('<span color="#b1222b"> </span>')

local function update_capslock()
	awful.spawn.easy_async_with_shell("xset q 2>/dev/null | grep -oP 'Caps Lock:\\s+\\K(on|off)'", function(out)
		local state = out and out:gsub("%s", "") or ""
		if state == "on" then
			capslock.widget:set_markup('<span color="#b1222b" weight="bold">CAPS</span>')
		else
			capslock.widget:set_markup('<span> </span>')
		end
	end)
end

-- Comprobar Caps Lock al inicio y cada 2s (ligero: xset q es rápido)
gears.timer({ timeout = 2, autostart = true, call_now = true, callback = update_capslock })

-- Software update indicator
--------------------------------------------------------------------------------
redflat.widget.updates:init({ command = env.updates, update_timeout = 300 })

local updates = {}
updates.widget = redflat.widget.updates()

updates.buttons = awful.util.table.join(
	awful.button({ }, 1, function () redflat.widget.updates:toggle() end),
	awful.button({ }, 2, function () redflat.widget.updates:update(true) end),
	awful.button({ }, 3, function () redflat.widget.updates:toggle() end)
)

-- Perfil de energía (powerprofilesctl): menú con clic derecho en batería
--------------------------------------------------------------------------------
local powerprofile = {}
do
	local profile_order = { "power-saver", "balanced", "performance" }
	local profile_label = {
		["power-saver"] = L("Saver"),
		["balanced"] = L("Balanced"),
		["performance"] = L("Performance"),
	}
	local micon = {
		blank = redutil.base.placeholder({ txt = " " }),
		check = redutil.base.placeholder({ txt = "✓" }),
	}

	-- Tema por fila: el perfil activo en rojo (color.main del tema)
	local function powerprofile_row_theme(selected)
		local base = powerprofile.menu and powerprofile.menu.theme or beautiful.menu or {}
		local t = redutil.table.merge({}, base)
		if selected then
			local main = (beautiful.color and beautiful.color.main) or "#0066CC"
			t.color = redutil.table.merge({}, t.color or {})
			t.color.text = main
			t.color.right_icon = main
		end
		return t
	end

	powerprofile._current = "balanced"
	powerprofile.menu = redmenu({
		hide_timeout = 2.5,
		nohide = true,
		theme = redutil.table.merge({ width = 220 }, beautiful.menu or {}),
		items = {},
	})

	function powerprofile:show_menu()
		-- Pantalla y área de trabajo fijadas aquí: en el callback async mouse.screen puede ser nil.
		local scr = awful.screen.focused()
		if not scr then
			local ms = mouse.screen
			if type(ms) == "number" then
				scr = screen[ms]
			else
				scr = ms
			end
		end
		if not scr and screen[1] then
			scr = screen[1]
		end
		local wa = scr and scr.workarea

		awful.spawn.easy_async_with_shell(
			"if command -v powerprofilesctl >/dev/null 2>&1; then powerprofilesctl get 2>/dev/null; else echo; fi",
			function(out)
				local p = (out or ""):gsub("^%s+", ""):gsub("%s+$", "")
				local ok = false
				for _, id in ipairs(profile_order) do
					if p == id then
						ok = true
						break
					end
				end
				powerprofile._available = ok
				if ok then
					powerprofile._current = p
				end

				local items = {}
				if not ok then
					items = { { L("Power profile unavailable"), function() end } }
				else
					for _, id in ipairs(profile_order) do
						local is_sel = powerprofile._current == id
						table.insert(items, {
							profile_label[id],
							function()
								local label_txt = profile_label[id]
								awful.spawn.easy_async_with_shell(
									"powerprofilesctl set " .. id .. " >/dev/null 2>&1",
									function(_, _, _, code)
										powerprofile._current = id
										if code == 0 then
											naughty.notify({
												title = L("Power profile"),
												text = string.format(L("Power profile: %s"), label_txt),
												timeout = 3,
											})
										end
									end
								)
								powerprofile.menu:hide()
							end,
							nil,
							is_sel and micon.check or micon.blank,
							theme = powerprofile_row_theme(is_sel),
						})
					end
				end

				powerprofile.menu:replace_items(items)
				if scr then
					powerprofile.menu.wibox.screen = scr
				end
				awful.placement.under_mouse(powerprofile.menu.wibox)
				if wa then
					redutil.placement.no_offscreen(powerprofile.menu.wibox, 0, wa)
				end
				powerprofile.menu:show({ coords = { x = powerprofile.menu.wibox.x, y = powerprofile.menu.wibox.y } })
			end
		)
	end
end

-- System resource monitoring widgets
--------------------------------------------------------------------------------
local sysmon = { widget = {}, buttons = {} }

local function first_battery_supply()
	for _, id in ipairs({ "BAT0", "BAT1", "BAT2" }) do
		local f = io.open("/sys/class/power_supply/" .. id .. "/present", "r")
		if f then
			f:close()
			return id
		end
	end
	return nil  -- sin batería
end

local bat_supply_id = first_battery_supply()

-- Batería: solo crear el widget si hay batería física
if bat_supply_id then
	-- Batería: battery.svg + franja roja desde abajo (como volumen); 0%% → battery-off.svg
	local bat_gauge_style = redutil.table.merge(beautiful.gauge.audio.blue or {}, {
		gauge = false,
		width = 28,
		icon = (beautiful.icon and beautiful.icon.battery)
			or ((beautiful.path or (awful.util.get_configuration_dir() .. "themes/Jiyu")) .. "/widget/battery.svg"),
		icon_muted = (beautiful.path or (awful.util.get_configuration_dir() .. "themes/Jiyu")) .. "/widget/battery-off.svg",
		icon_input_meter = true,
		icon_fill_from_bottom = true,
		icon_mute_at_zero = true,
	})
	sysmon.widget.battery = redflat.widget.battery(
		{ func = redflat.system.pformatted.bat(25), arg = bat_supply_id },
		{ timeout = 30, widget = redflat.gauge.audio.blue, monitor = bat_gauge_style,
		  notify = { preset = { title = "Batería baja", text = "Conecta el cargador" } },
		  levels = { 0.05, 0.1, 0.15, 0.20 }
		}
	)
end

sysmon.buttons.battery = awful.util.table.join(
	awful.button({}, 2, function()
		local st = redflat.system.battery(bat_supply_id)
		if not st then
			return
		end
		local state_names = { ["+"] = "Cargando", ["-"] = "Descargando", ["↯"] = "Cargado", ["⌁"] = "Desconocido" }
		local state_text = state_names[st[1]] or st[1]
		naughty.notify({
			title = "Batería (" .. bat_supply_id .. ")",
			text = string.format("Estado: %s\nCarga: %d%%\nTiempo restante: %s", state_text, st[2], st[3]),
			timeout = 8,
		})
	end),
	awful.button({}, 3, function()
		powerprofile:show_menu()
	end)
)

-- Red: up.svg / down.svg + rojo desde abajo según consumo (sin icon_muted del tema de volumen).
-- Timeout 1s para monitorización en tiempo real
local net_speed = { up = 6 * 1024^2, down = 6 * 1024^2 }
local _net_wdir = (beautiful.path or (awful.util.get_configuration_dir() .. "themes/Jiyu")) .. "/widget/"
local function net_gauge_monitor(icon_path)
	local s = redutil.table.merge(beautiful.gauge.audio.blue or {}, {
		gauge = false,
		width = 28,
		icon = icon_path,
		icon_input_meter = true,
		icon_fill_from_bottom = true,
		icon_mute_at_zero = false,
	})
	s.icon_muted = nil
	return s
end
sysmon.widget.network_up = redflat.widget.net(
	{
		interface = "auto",
		speed = net_speed,
		autoscale = false,
		alert_ratio = 0.8,
		direction = "up",
	},
	{
		timeout = 1,
		widget = redflat.gauge.audio.blue,
		monitor = net_gauge_monitor(
			(beautiful.icon and beautiful.icon.up) or (_net_wdir .. "up.svg")
		),
	}
)
sysmon.widget.network_down = redflat.widget.net(
	{
		interface = "auto",
		speed = net_speed,
		autoscale = false,
		alert_ratio = 0.8,
		direction = "down",
	},
	{
		timeout = 1,
		widget = redflat.gauge.audio.blue,
		monitor = net_gauge_monitor(
			(beautiful.icon and beautiful.icon.down) or (_net_wdir .. "down.svg")
		),
	}
)

-- Speedtest popup visual (librespeed-cli o speedtest-cli)
-- Posición: bajo el ratón (igual que el menú de red)
--------------------------------------------------------------------------------
local speedtest_popup = { wibox = nil, loading = false }

local function speedtest_close_popup()
	if speedtest_popup.wibox then
		speedtest_popup.wibox.visible = false
		speedtest_popup.wibox = nil
	end
	speedtest_popup.loading = false
end

local function speedtest_theme()
	local is_light = beautiful.color and beautiful.color.scheme == "light"
	return {
		bg     = is_light and "#ffffffee" or "#1a1a1aee",
		border = is_light and "#c0c0c0"   or "#444444",
		txt    = is_light and "#333333"   or "#e0e0e0",
		main   = (beautiful.color and beautiful.color.main) or "#0066CC",
	}
end

local function speedtest_show_popup(content_widgets, clickable)
	speedtest_close_popup()

	local th = speedtest_theme()

	local layout = wibox.layout.fixed.vertical()
	layout.spacing = 6
	for _, w in ipairs(content_widgets) do
		layout:add(w)
	end

	local scr = awful.screen.focused()
	local wa = scr and scr.workarea or screen[1].workarea
	local pw, ph = 340, 220

	speedtest_popup.wibox = wibox({
		ontop = true,
		visible = true,
		bg = th.bg,
		border_width = 2,
		border_color = th.border,
		shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 12) end,
	})
	speedtest_popup.wibox:setup {
		{
			layout,
			margins = 16,
			widget = wibox.container.margin,
		},
		layout = wibox.container.background,
	}

	-- Posición: bajo el ratón (igual que netctl/bluetooth)
	awful.placement.under_mouse(speedtest_popup.wibox)
	-- Ajustar para que no se salga de pantalla
	local geo = speedtest_popup.wibox:geometry()
	if geo.x + pw > wa.x + wa.width then
		speedtest_popup.wibox:geometry({ x = wa.x + wa.width - pw - 4 })
	end
	if geo.y + ph > wa.y + wa.height then
		speedtest_popup.wibox:geometry({ y = wa.y + wa.height - ph - 4 })
	end
	speedtest_popup.wibox:geometry({ width = pw, height = ph })

	-- Solo cerrar con click si no está cargando
	if clickable then
		speedtest_popup.wibox:buttons(awful.util.table.join(
			awful.button({}, 1, speedtest_close_popup),
			awful.button({}, 3, speedtest_close_popup)
		))
	end
end

local function speedtest_show_results(json_str, is_librespeed)
	local th = speedtest_theme()
	speedtest_popup.loading = false

	if not json_str or json_str == "" or json_str:match("^NO_SPEEDTEST") then
		local err = wibox.widget {
			markup = '<span color="' .. th.txt .. '">' .. L("Speed test") .. '\n\n' .. L("Install librespeed-cli or speedtest-cli") .. '</span>',
			font = "Lato 10",
			align = "center",
			widget = wibox.widget.textbox,
		}
		speedtest_show_popup({ err }, true)
		return
	end

	-- Limpiar: el fichero solo contiene el JSON; quitar espacios/saltos sobrantes.
	json_str = json_str:match("(%b{})") or json_str

	local ping = json_str:match('"ping":%s*([%d.]+)')
	local down = json_str:match('"download":%s*([%d.]+)')
	local up   = json_str:match('"upload":%s*([%d.]+)')
	local div  = is_librespeed and 1 or 1e6

	local server_name = json_str:match('"server":%s*{[^}]*"name":%s*"([^"]+)"')
	             or json_str:match('"name":"([^"]+)"')
	local client_ip = json_str:match('"client":%s*{[^}]*"ip":%s*"([^"]+)"')
	            or json_str:match('"ip":"([^"]+)"')

	local title = wibox.widget {
		markup = '<span color="' .. th.main .. '" size="larger"><b>' .. L("Speed test results") .. '</b></span>',
		font = "Lato 10",
		align = "center",
		widget = wibox.widget.textbox,
	}

	local sep = wibox.widget {
		forced_height = 1,
		widget = wibox.widget.separator,
		orientation = "horizontal",
		color = th.border,
		span_ratio = 1.0,
		thickness = 1,
	}

	local function stat_row(label, value, unit)
		return wibox.widget {
			{
				{
					markup = '<span color="' .. th.txt .. '">' .. label .. '</span>',
					font = "Lato 10",
					widget = wibox.widget.textbox,
				},
				{
					markup = '<span color="' .. th.main .. '"><b>' .. value .. '</b></span> <span color="' .. th.txt .. '">' .. unit .. '</span>',
					font = "Lato 10",
					align = "right",
					expand = "inside",
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.align.horizontal,
			},
			left = 4, right = 4, top = 2, bottom = 2,
			widget = wibox.container.margin,
		}
	end

	local widgets = { title, sep }
	table.insert(widgets, stat_row(L("Download"), down and string.format("%.1f", tonumber(down) / div) or "?", "Mbps"))
	table.insert(widgets, stat_row(L("Upload"),   up   and string.format("%.1f", tonumber(up)   / div) or "?", "Mbps"))
	table.insert(widgets, stat_row(L("Ping"),     ping or "?", "ms"))

	if server_name and server_name ~= "" then
		table.insert(widgets, sep)
		table.insert(widgets, stat_row(L("Server"), server_name, ""))
	end
	if client_ip and client_ip ~= "" then
		table.insert(widgets, stat_row(L("IP"), client_ip, ""))
	end

	local hint = wibox.widget {
		markup = '<span size="small" color="' .. th.txt .. '">' .. L("Click to close") .. '</span>',
		font = "Lato 9",
		align = "center",
		widget = wibox.widget.textbox,
	}
	table.insert(widgets, hint)

	speedtest_show_popup(widgets, true)
end

local function run_speedtest()
	local th = speedtest_theme()

	-- Popup inicial: "ejecutando…" (no se puede cerrar con click)
	speedtest_popup.loading = true
	local loading = wibox.widget {
		markup = '<span color="' .. th.txt .. '">' .. L("Speed test") .. '\n\n' .. L("Running… this takes ~30s") .. '</span>',
		font = "Lato 10",
		align = "center",
		widget = wibox.widget.textbox,
	}
	speedtest_show_popup({ loading }, false)

	-- Lanzar speedtest en background escribiendo a un fichero temporal.
	-- easy_async_with_shell puede no capturar output de procesos largos (>30s),
	-- así que usamos with_shell + timer que poll el fichero.
	local tmpfile = "/tmp/awesome-speedtest-result.txt"
	local donefile = "/tmp/awesome-speedtest-done.txt"
	awful.spawn.with_shell(string.format(
		[[bash -c 'rm -f "%s" "%s"; (command -v librespeed-cli-linux-amd64 >/dev/null 2>&1 && librespeed-cli-linux-amd64 --json > "%s" 2>&1 && echo "LIBRESPEED" > "%s") || (command -v librespeed-cli >/dev/null 2>&1 && librespeed-cli --json > "%s" 2>&1 && echo "LIBRESPEED" > "%s") || (command -v speedtest-cli >/dev/null 2>&1 && speedtest-cli --json > "%s" 2>&1 && echo "SPEEDTEST_CLI" > "%s") || echo "NO_SPEEDTEST" > "%s"; echo "DONE" >> "%s"']],
		tmpfile, donefile, tmpfile, donefile, tmpfile, donefile, tmpfile, donefile, donefile, donefile
	))

	-- Timer: poll cada 2s hasta que el fichero "done" aparezca
	local attempts = 0
	local max_attempts = 45  -- 90s máximo
	local poll_timer
	poll_timer = gears.timer({ timeout = 2 })
	poll_timer:connect_signal("timeout", function()
		attempts = attempts + 1
		-- Si el popup se cerró manualmente, parar el timer
		if not speedtest_popup.wibox then
			poll_timer:stop()
			return
		end
		-- Si pasó demasiado tiempo, mostrar error
		if attempts > max_attempts then
			poll_timer:stop()
			speedtest_popup.loading = false
			local err = wibox.widget {
				markup = '<span color="' .. th.txt .. '">' .. L("Speed test") .. '\n\n' .. L("Timeout — try again") .. '</span>',
				font = "Lato 10",
				align = "center",
				widget = wibox.widget.textbox,
			}
			speedtest_show_popup({ err }, true)
			return
		end

		-- Leer fichero "done" para saber qué herramienta se usó
		local done_handle = io.open(donefile, "r")
		if not done_handle then return end  -- aún no terminó
		local marker = done_handle:read("*a") or ""
		done_handle:close()

		-- Solo proceder si el proceso terminó (marcador DONE presente)
		if not marker:match("DONE") then return end

		poll_timer:stop()

		-- Leer resultados
		local result_handle = io.open(tmpfile, "r")
		local json_str = ""
		if result_handle then
			json_str = result_handle:read("*a") or ""
			result_handle:close()
		end
		awful.spawn.with_shell(string.format('rm -f "%s" "%s"', tmpfile, donefile))

		local is_librespeed = marker:match("LIBRESPEED")
		if marker:match("NO_SPEEDTEST") then
			json_str = "NO_SPEEDTEST"
		end

		speedtest_show_results(json_str, is_librespeed)
	end)
	poll_timer:start()
end

sysmon.buttons.network = awful.util.table.join(
	awful.button({}, 1, function() redflat.float.netctl:show() end),
	awful.button({}, 3, run_speedtest)
)

-- También accesible por atajo: Mod4+c u s
env.run_speedtest = run_speedtest

-- Temperature widget (icono circular como CPU/RAM; clic abre popup de sensores)
--------------------------------------------------------------------------------
local temp_widget = {}
temp_widget.widget = redflat.widget.sysmon(
	{ func = redflat.system.pformatted.temp(75) },
	{ timeout = 5, widget = redflat.gauge.monitor.circle }
)

-- Popup flotante con la salida completa de `sensors`
temp_widget.buttons = awful.util.table.join(
	awful.button({}, 1, function() redflat.float.sensors:show() end),
	awful.button({}, 3, function() redflat.float.sensors:show() end)
)

-- Bluetooth (icono + menú: encender/apagar, conectar emparejados; opcional env.bluetooth_manager)
--------------------------------------------------------------------------------
local bluetooth = {}
do
	local ok, w = pcall(function()
		return redflat.widget.bluetooth({ manager_cmd = env.bluetooth_manager })
	end)
	if ok then
		bluetooth.widget = w
		bluetooth.buttons = awful.util.table.join(
			awful.button({}, 1, function() redflat.widget.bluetooth:toggle_menu() end),
			awful.button({}, 3, function() redflat.widget.bluetooth:toggle_menu() end)
		)
	end
end

-- CPU usage (indicador circular)
sysmon.widget.cpu = redflat.widget.sysmon(
	{ func = redflat.system.pformatted.cpu(80) },
	{ timeout = 2, widget = redflat.gauge.monitor.circle }
)

	sysmon.buttons.cpu = awful.util.table.join(
		awful.button({}, 1, function() redflat.float.top_cpu:show() end),
		awful.button({}, 3, function() redflat.float.top_cpu:show() end)
)

-- RAM usage (indicador circular)
sysmon.widget.ram = redflat.widget.sysmon(
	{ func = redflat.system.pformatted.mem(70) },
	{ timeout = 1, widget = redflat.gauge.monitor.circle }
)

	sysmon.buttons.ram = awful.util.table.join(
		awful.button({}, 1, function() redflat.float.top_mem:show() end),
		awful.button({}, 3, function() redflat.float.top_mem:show() end)
)


-- Screen setup
-----------------------------------------------------------------------------------------------------------------------

-- setup
awful.screen.connect_for_each_screen(
	function(s)
		-- wallpaper: set_wallpaper se conecta más abajo (una sola fuente, sin duplicar)

		-- tags: nombres distintos por pantalla (pantalla 1 = 1-6, pantalla 2 = 7-12, ...)
		local sidx = s.index or 1
		local s_names = {}
		for i = 1, #taglist.names do
			s_names[i] = tostring((sidx - 1) * #taglist.names + i)
		end
		awful.tag(s_names, s, taglist.layouts)

		-- layoutbox widget
		layoutbox[s] = redflat.widget.layoutbox({ screen = s })

		-- taglist widget: layout grid propio por pantalla (si se comparte, ambas se pisan)
		local s_taglayout = wibox.widget {
			expand          = true,
			forced_num_rows = taglist.rows_num,
			forced_num_cols = taglist.cols_num,
			layout          = wibox.layout.grid,
		}
		taglist[s] = redflat.widget.taglist(
			{ screen = s, buttons = taglist.buttons, hint = env.tagtip, layout = s_taglayout }, taglist.style
		)

		-- tasklist widget
		tasklist[s] = redflat.widget.tasklist({ screen = s, buttons = tasklist.buttons }, tasklist.style)

		-- Panel: colores del tema Jiyu (fallback si beautiful quedó incompleto tras init).
		local panel_bg = beautiful.bg_normal or (beautiful.color and beautiful.color.wibox) or "#d0d0d0"
		local panel_fg = beautiful.fg_normal or (beautiful.color and beautiful.color.text) or "#000000"
		s.panel = awful.wibar({
			position = "bottom",
			screen   = s,
			height   = beautiful.panel_height or 36,
			bg       = panel_bg,
			fg       = panel_fg,
			visible  = true,
			opacity  = 1,
		})

		-- Zona derecha: no usar nil en wibox.layout.fixed.horizontal (rompe el layout del panel).
		local panel_right = wibox.layout.fixed.horizontal()
		panel_right:add(panel_separator())
		panel_right:add(env.wrapper(sysmon.widget.cpu, "cpu", sysmon.buttons.cpu))
		panel_right:add(env.wrapper(sysmon.widget.ram, "ram", sysmon.buttons.ram))
		if temp_widget.widget then
			panel_right:add(env.wrapper(temp_widget.widget, "temp", temp_widget.buttons))
		end
		if sysmon.widget.battery then
			panel_right:add(env.wrapper(sysmon.widget.battery, "battery", sysmon.buttons.battery))
		end
		panel_right:add(panel_separator())
		panel_right:add(env.wrapper(sysmon.widget.network_down, "network_down", sysmon.buttons.network))
		panel_right:add(env.wrapper(sysmon.widget.network_up, "network_up", sysmon.buttons.network))
		panel_right:add(panel_separator())
		if bluetooth.widget then
			panel_right:add(env.wrapper(bluetooth.widget, "bluetooth", bluetooth.buttons))
		end
		panel_right:add(env.wrapper(microphone.widget, "microphone", microphone.buttons))
		panel_right:add(env.wrapper(volume.widget, "volume", volume.buttons))
		if backlight.widget then
			panel_right:add(env.wrapper(backlight.widget, "brightness", backlight.buttons))
		end
		panel_right:add(panel_separator())
		panel_right:add(env.wrapper(textclock.widget, "textclock", textclock.buttons))
		panel_right:add(panel_separator())
		panel_right:add(env.wrapper(tray.widget, "tray", tray.buttons))

		-- Panel: un solo align (izquierda | centro expandible | derecha).
		-- Un align anidado + expand="outside" con solo 2 hijos dejaba el tasklist sin sitio o invisible.
		s.panel:setup {
			layout = wibox.layout.align.horizontal,
			{ -- left
				layout = wibox.layout.fixed.horizontal,

				env.wrapper(layoutbox[s], "layoutbox", layoutbox.buttons),
				panel_separator(),
				env.wrapper(taglist[s], "taglist"),
				panel_separator(),
				env.wrapper(kbindicator.widget, "keyboard", kbindicator.buttons),
				capslock.widget,
				panel_separator(),
				env.wrapper(updates.widget, "updates", updates.buttons),
				panel_separator(),
			},
			{
				{
					env.wrapper(tasklist[s], "tasklist"),
					halign = "center",
					valign = "center",
					widget = wibox.container.place,
				},
				layout = wibox.layout.flex.horizontal,
			},
			panel_right,
		}
	end
)

-- Wallpaper: una sola fuente (env.wallpaper lee beautiful.wallpaper del tema,
-- con fallback a color de fondo). Cada tema define wallpaper-dark/-light.png.
awful.screen.connect_for_each_screen(env.wallpaper)
screen.connect_signal("property::geometry", env.wallpaper)


-- Desktop widgets
-----------------------------------------------------------------------------------------------------------------------
if not lock.desktop then
	local desktop = require("Jiyu.desktop-config") -- load file with desktop widgets configuration
	desktop:init({
		env = env,
		buttons = awful.util.table.join(awful.button({}, 3, function () mymenu.mainmenu:toggle() end))
	})
end


-- Active screen edges
-----------------------------------------------------------------------------------------------------------------------
local edges = require("Jiyu.edges-config") -- load file with edges configuration
edges:init({ tag_cols_num = taglist.cols_num })


-- Log out screen
-----------------------------------------------------------------------------------------------------------------------
local oblogout_cfg = require("Jiyu.oblogout-config")
oblogout_cfg:init()


-- Key bindings
-----------------------------------------------------------------------------------------------------------------------
local appkeys = require("Jiyu.appkeys-config") -- load file with application keys sheet

local hotkeys = require("Jiyu.keys-config") -- load file with hotkeys configuration
hotkeys:init({
	env = env, menu = mymenu.mainmenu, appkeys = appkeys, tag_cols_num = taglist.cols_num,
	microphone = microphone.widget, volume = volume.widget,
	show_hotkeys_on_startup = SHOW_HOTKEYS_POPUP_ON_STARTUP
 })


-- Rules
-----------------------------------------------------------------------------------------------------------------------
local rules = require("Jiyu.rules-config") -- load file with rules configuration
rules:init({ env = env, hotkeys = hotkeys })


-- Titlebar setup
-----------------------------------------------------------------------------------------------------------------------
local titlebar = require("Jiyu.titlebar-config") -- load file with titlebar configuration
titlebar:init()


-- Base signal set for awesome wm
-----------------------------------------------------------------------------------------------------------------------
local signals = require("Jiyu.signals-config") -- load file with signals configuration
signals:init({ env = env })


-- Autostart user applications
-----------------------------------------------------------------------------------------------------------------------
if redflat.startup.is_startup then
	local autostart = require("Jiyu.autostart-config") -- load file with autostart application list
	autostart.run()
end
