-----------------------------------------------------------------------------------------------------------------------
--                                                Signals config                                                     --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local redutil  = require("redflat.util")

-- Rounded corners radius (px); 0 = desactivado
local CORNER_RADIUS = 8

local function set_shape(c)
	if c.fullscreen or c.maximized or c.maximized_horizontal or c.maximized_vertical then
		c.shape = gears.shape.rectangle
	else
		c.shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, CORNER_RADIUS) end
	end
end

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local signals = {}

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function do_sloppy_focus(c)
	if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier and awful.client.focus.filter(c) then
		client.focus = c
	end
end

local function fixed_maximized_geometry(c, context)
	if c.maximized and context ~= "fullscreen" then
		c:geometry({
			x = c.screen.workarea.x,
			y = c.screen.workarea.y,
			height = c.screen.workarea.height - 2 * c.border_width,
			width = c.screen.workarea.width - 2 * c.border_width
		})
	end
end

-- Build  table
-----------------------------------------------------------------------------------------------------------------------
function signals:init(args)

	args = args or {}
	local env = args.env

	-- actions on every application start
	client.connect_signal(
		"manage",
		function(c)
			-- put client at the end of list
			if env.set_slave then awful.client.setslave(c) end

			-- startup placement
			if awesome.startup
			   and not c.size_hints.user_position
			   and not c.size_hints.program_position
			then
				awful.placement.no_offscreen(c)
			end

			-- put new floating windows to the center of screen
			if env.set_center and c.floating and not (c.maximized or c.fullscreen) then
				redutil.placement.centered(c, nil, c.screen.workarea)
			end

			-- rounded corners
			set_shape(c)
		end
	)

	-- update shape when maximized/fullscreen state changes
	for _, prop in ipairs({ "maximized", "maximized_horizontal", "maximized_vertical", "fullscreen" }) do
		client.connect_signal("property::" .. prop, set_shape)
	end

	-- add missing borders to windows that get unmaximized
	client.connect_signal(
		"property::maximized",
		function(c)
			if not c.maximized then
				c.border_width = beautiful.border_width
			end
		end
	)

	-- don't allow maximized windows move/resize themselves
	client.connect_signal(
		"request::geometry", fixed_maximized_geometry
	)

	-- enable sloppy focus, so that focus follows mouse
	if env.sloppy_focus then
		client.connect_signal("mouse::enter", do_sloppy_focus)
	end

	-- drag-to-focus: polling cada 200 ms mientras el botón 1 está pulsado.
	-- mouse::enter NO se dispara durante un drag (X11 tiene el puntero capturado),
	-- por eso usamos un timer que lee la posición del ratón y busca la ventana bajo él.
	-- xdotool es opcional: solo se usa para forzar el foco X11 real (necesario para Xdnd).
	local _has_xdotool = os.execute("command -v xdotool >/dev/null 2>&1")
	local _drag_last = nil   -- última ventana detectada, para no repetir xdotool
	local _drag_timer = gears.timer({
		timeout  = 0.2,
		callback = function()
			local coords = mouse.coords()
			if not coords.buttons[1] then
				_drag_last = nil
				return
			end

			-- ventana bajo el cursor
			local c = mouse.object_under_pointer()
			if type(c) ~= "client" then return end
			if c == _drag_last then return end
			_drag_last = c

			if c.minimized then c.minimized = false end
			if not c:isvisible() then
				awful.tag.viewmore(c:tags(), c.screen)
			end
			client.focus = c
			c:raise()
			-- foco X11 real para que Xdnd complete la transferencia (solo si xdotool existe)
			-- sin --sync para no bloquear el timer
			if _has_xdotool and c.window then
				awful.spawn("xdotool windowfocus " .. tostring(c.window), false)
			end
		end,
	})
	_drag_timer:start()

	-- hilight border of focused window
	-- can be disabled since focus indicated by titlebars in current config
	if env.color_border_focus then
		client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus end)
		client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
	end

	-- wallpaper update on screen geometry change (set_wallpaper en rc-Jiyu.lua maneja esto)
	-- screen.connect_signal("property::geometry", env.wallpaper) -- eliminado: duplicado

	-- Reinicio al conectar/desconectar monitor — redflat panel no soporta multi-screen dinámico.
	-- Debounce de 1 s: evita reinicios en cascada cuando el sistema emite varios eventos seguidos
	-- (frecuente con docks USB-C o al conectar HDMI mientras el driver inicializa).
	local _restart_timer = gears.timer({
		timeout   = 1,
		single_shot = true,
		callback  = awesome.restart,
	})
	screen.connect_signal("list", function()
		_restart_timer:again()
	end)

	-- Picom watchdog: comprueba cada 60s si picom vive y lo relanza si crasheó.
	gears.timer({
		timeout = 60,
		autostart = true,
		call_now = false,
		callback = function()
			awful.spawn.easy_async_with_shell(
				[[pgrep -x picom > /dev/null || picom -d --config /dev/null --backend glx --vsync --fading --shadow --shadow-radius 7 --shadow-offset-x -7 --shadow-offset-y -7 --shadow-exclude "window_type = 'desktop' || window_type = 'dock'"]],
				function() end
			)
		end,
	})
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return signals
