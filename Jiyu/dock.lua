-----------------------------------------------------------------------------------------------------------------------
--                                                   Floating dock                                                    --
-----------------------------------------------------------------------------------------------------------------------
-- Dock flotante estilo macOS para lanzar aplicaciones
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local menubar = require("menubar")

local dock = { wibox = nil, visible = false }

-- Lista de aplicaciones favoritas (todas instaladas en el sistema)
local apps = {
	{ name = "Librewolf", icon = "/usr/share/icons/hicolor/48x48/apps/librewolf.png", command = "librewolf" },
	{ name = "Guake", icon = "/usr/share/icons/hicolor/48x48/apps/guake.png", command = "guake --toggle-visibility" },
	{ name = "Terminal", icon = "/usr/share/pixmaps/Alacritty.svg", command = "alacritty" },
	{ name = "Files", icon = "/usr/share/icons/hicolor/22x22/apps/nemo.png", command = "nemo" },
	{ name = "Editor", icon = "/usr/share/icons/hicolor/48x48/apps/geany.png", command = "geany" },
	{ name = "VS Code", icon = "/usr/share/icons/hicolor/scalable/apps/com.visualstudio.code.oss.svg", command = "code" },
}

-- Crear el dock
function dock.new()
	-- Detectar si es tema claro u oscuro usando la bandera canónica scheme
	local is_light = beautiful.color and beautiful.color.scheme == "light"
	
	-- Colores según tema
	local theme_bg, theme_border, theme_main, hover_color
	if is_light then
		-- Tema claro (JiyuLight)
		theme_bg = "#d0d0d0cc"
		theme_border = "#b0b0b0"
		theme_main = beautiful.color and beautiful.color.main or "#0066CC"
		hover_color = theme_main .. "30"
	else
		-- Tema oscuro (Jiyu)
		theme_bg = "#2a2a2acc"
		theme_border = "#444444"
		theme_main = beautiful.color and beautiful.color.main or "#b1222b"
		hover_color = theme_main .. "30"
	end

	local dock_wibox = wibox({
		ontop        = true,
		visible      = false,
		bg           = theme_bg,
		border_width = 2,
		border_color = theme_border,
		shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 12) end,
	})

	-- Crear layout horizontal para los iconos
	local layout = wibox.layout.fixed.horizontal()
	layout.spacing = 10

	-- Añadir iconos de aplicaciones
	for _, app in ipairs(apps) do
		local icon_widget = wibox.widget.imagebox()
		-- gears.surface.load renderiza SVG vía librsvg; imagebox directo a veces falla con SVG
		local ok, surface = pcall(gears.surface.load, app.icon)
		if ok and surface then
			icon_widget:set_image(surface)
		else
			-- fallback: intentar como path directo
			icon_widget:set_image(app.icon)
		end

		local container = wibox.widget {
			icon_widget,
			margins = 8,
			widget = wibox.container.margin,
		}

		local background = wibox.widget {
			container,
			widget = wibox.container.background,
			bg = "#00000000",
		}

		-- Hover effect
		background:connect_signal("mouse::enter", function()
			background.bg = hover_color
		end)

		background:connect_signal("mouse::leave", function()
			background.bg = "#00000000"
		end)

		-- Click to launch
		background:connect_signal("button::press", function()
			awful.spawn(app.command)
		end)

		layout:add(background)
	end

	dock_wibox:set_widget(wibox.container.margin(layout, 10, 10, 10, 10))

	return dock_wibox
end

-- Mostrar el dock
function dock:show()
	if not self.wibox then
		self.wibox = dock.new()
	end

	local screen = awful.screen.focused()
	if not screen then return end
	local workarea = screen.workarea
	local dock_height = 80
	local dock_width = 480

	self.wibox.screen = screen
	self.wibox:geometry({
		x = workarea.x + (workarea.width - dock_width) / 2,
		y = workarea.y + 20, -- Arriba del escritorio
		width = dock_width,
		height = dock_height,
	})

	self.wibox.visible = true
	self.visible = true
end

-- Ocultar el dock
function dock:hide()
	if self.wibox then
		self.wibox.visible = false
		self.visible = false
	end
end

-- Toggle dock
function dock:toggle()
	if self.visible then
		self:hide()
	else
		self:show()
	end
end

return dock
