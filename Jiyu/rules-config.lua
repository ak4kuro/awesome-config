-----------------------------------------------------------------------------------------------------------------------
--                                                Rules config                                                       --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful =require("awful")
local beautiful = require("beautiful")
local redtitle = require("redflat.titlebar")

-- Initialize tables and vars for the module
-----------------------------------------------------------------------------------------------------------------------
local rules = {}

rules.base_properties = {
	border_width     = beautiful.border_width,
	border_color     = beautiful.border_normal,
	focus            = awful.client.focus.filter,
	raise            = true,
	size_hints_honor = false,
	screen           = awful.screen.preferred,
}

rules.floating_any = {
	class = {
		"Clipflap", "Run.py",
		-- gestores de red / audio / bluetooth
		"Pavucontrol", "Blueman-manager", "Blueberry",
		-- configuración de displays
		"Arandr", "Wdisplays",
		-- herramientas del sistema
		"Gpaste", "Gpaste-client",
		-- apps ligeras que funcionan mejor flotando
		"Galculator", "Gnome-calculator", "Kcalc",
		"Eog", "Shotwell", "Viewnior",
		"Font-manager",
		"Nm-connection-editor",
		"System-config-printer.py",
		-- instaladores
		"Pamac", "Pamac-manager", "Pamac-updater",
		"Zenity", "Yad",
	},
	role = { "AlarmWindow", "pop-up", "GtkFileChooserDialog", "response" },
	type = { "dialog" }
}

rules.titlebar_exceptions = {
	class = { "Cavalcade", "Clipflap", "Steam", "Qemu-system-x86_64" }
}

rules.maximized = {
	class = { "Emacs24" }
}

-- Build rule table
-----------------------------------------------------------------------------------------------------------------------
function rules:init(args)

	args = args or {}
	self.base_properties.keys = args.hotkeys.keys.client
	self.base_properties.buttons = args.hotkeys.mouse.client
	self.env = args.env or {}


	-- Build rules
	--------------------------------------------------------------------------------
	self.rules = {
		{
			rule       = {},
			properties = args.base_properties or self.base_properties
		},
		{
			rule_any   = args.floating_any or self.floating_any,
			properties = { floating = true }
		},
		{
			rule_any   = self.maximized,
			callback = function(c)
				c.maximized = true
				redtitle.cut_all({ c })
				c.height = c.screen.workarea.height - 2 * c.border_width
			end
		},
		{
			rule_any   = { type = { "normal", "dialog" }},
			except_any = self.titlebar_exceptions,
			properties = { titlebars_enabled = true }
		},
		{
			rule_any   = { type = { "normal" }},
			properties = { placement = awful.placement.no_overlap + awful.placement.no_offscreen }
		},

		-- Tags placement: por índice (no por nombre) para que funcione en cualquier pantalla
		{
			rule = { instance = "Xephyr" },
			properties = { fullscreen = true },
			callback = function(c)
				local t = c.screen.tags[1]
				if t then c:move_to_tag(t) end
			end
		},
		-- Apps en tags específicos (índice 2-6, funciona en cualquier pantalla)
		{
			rule_any = { class = { "Librewolf", "Firefox", "Chromium" } },
			callback = function(c)
				local t = c.screen.tags[2]
				if t then c:move_to_tag(t) end
			end
		},
		{
			rule_any = { class = { "Geany", "Code", "Code-OSS", "VSCodium" } },
			callback = function(c)
				local t = c.screen.tags[3]
				if t then c:move_to_tag(t) end
			end
		},
		{
			rule_any = { class = { "Thunar", "Nemo", "Pcmanfm" } },
			callback = function(c)
				local t = c.screen.tags[4]
				if t then c:move_to_tag(t) end
			end
		},
		{
			rule_any = { class = { "Spotify", "Pragha", "Audacious", "Cmus" } },
			callback = function(c)
				local t = c.screen.tags[5]
				if t then c:move_to_tag(t) end
			end
		},
		{
			rule_any = { class = { "Thunderbird", "Deltachat-desktop" } },
			callback = function(c)
				local t = c.screen.tags[6]
				if t then c:move_to_tag(t) end
			end
		},
		-- Guake siempre flotante y sin barra de título
		{
			rule = { class = "Guake" },
			properties = { floating = true, titlebars_enabled = false, ontop = true }
		},

		-- Jetbrains splash screen fix
		{
			rule_any = { class = { "jetbrains-%w+", "java-lang-Thread" } },
			callback = function(jetbrains)
				if jetbrains.skip_taskbar then jetbrains.floating = true end
			end
		},
	}


	-- Set rules
	--------------------------------------------------------------------------------
	awful.rules.rules = rules.rules
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return rules