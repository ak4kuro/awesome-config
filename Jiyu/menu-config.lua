-----------------------------------------------------------------------------------------------------------------------
--                                                  Menu config                                                      --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local beautiful = require("beautiful")
local redflat = require("redflat")
local awful = require("awful")
local L = require("Jiyu.locale").t


-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local menu = {}


-- Build function
-----------------------------------------------------------------------------------------------------------------------
function menu:init(args)

	-- vars
	args = args or {}
	local env = args.env or {} -- fix this?
	local separator = args.separator or { widget = redflat.gauge.separator.horizontal() }
	local theme = args.theme or { auto_hotkey = true }
	local theme_path = beautiful.path or (awful.util.get_configuration_dir() .. "themes/Jiyu")
	local M = theme_path .. "/icons/menu"

	-- Iconos de apps del sistema: busca en /usr/share/icons; fallback = icono genérico gris propio
	local app_icon_style = { custom_only = false, scalable_only = false, df_icon = M .. "/applications.svg" }
	-- Iconos del menú principal y categorías: siempre desde M (SVGs grises propios)
	local function menu_icon(name, fallback)
		return (fallback ~= nil and fallback ~= "") and fallback or (M .. "/" .. name .. ".svg")
	end

	local icon = redflat.util.table.check(beautiful, "icon.awesome") and beautiful.icon.awesome
		or (M .. "/awesome.svg")

	-- extra commands
	local ranger_comm = env.terminal .. " -e ranger"

	-- Application submenu — iconos de sistema con fallback gris
	------------------------------------------------------------
	local appmenu = redflat.service.dfparser.menu({ icons = app_icon_style, wm_name = "awesome" })
	-- Parchar categorías para usar nuestros SVGs grises
	local cat_icons = {
		Multimedia   = M .. "/cat-multimedia.svg",
		Development  = M .. "/cat-development.svg",
		Education    = M .. "/cat-education.svg",
		Games        = M .. "/cat-games.svg",
		Graphics     = M .. "/cat-graphics.svg",
		Office       = M .. "/cat-office.svg",
		Internet     = M .. "/cat-internet.svg",
		Settings     = M .. "/cat-settings.svg",
		["System Tools"] = M .. "/cat-system.svg",
		Accessories  = M .. "/cat-accessories.svg",
		Other        = M .. "/applications.svg",
	}
	for _, cat in ipairs(appmenu) do
		if type(cat) == "table" and type(cat[1]) == "string" and cat_icons[cat[1]] then
			cat[3] = cat_icons[cat[1]]
		end
	end

	-- Awesome submenu
	------------------------------------------------------------
	local awesomemenu = {
		{ L("Restart"),         awesome.restart,                 menu_icon("gnome-session-reboot", M .. "/restart.svg") },
		separator,
		{ L("Awesome config"),  env.fm .. " .config/awesome",        menu_icon("folder-bookmarks", M .. "/folder-config.svg") },
		{ L("Awesome lib"),     env.fm .. " /usr/share/awesome/lib", menu_icon("folder-bookmarks", M .. "/code-lib.svg") },
		{ L("Display settings"), env.display_config or "arandr",      menu_icon("video-display", M .. "/display.svg") }
	}

	-- Places submenu
	------------------------------------------------------------
	local placesmenu = {
		{ L("Documents"),   env.fm .. " Documents", menu_icon("folder-documents", M .. "/folder-documents.svg") },
		{ L("Downloads"),   env.fm .. " Downloads", menu_icon("folder-download", M .. "/folder-download.svg")  },
		{ L("Music"),       env.fm .. " Music",     menu_icon("folder-music", M .. "/folder-music.svg")     },
		{ L("Pictures"),    env.fm .. " Pictures",  menu_icon("folder-pictures", M .. "/folder-pictures.svg")  },
		{ L("Videos"),      env.fm .. " Videos",    menu_icon("folder-videos", M .. "/folder-videos.svg")    },
		separator,
		{ L("Media"),       env.fm .. " /mnt/media",   menu_icon("folder-bookmarks", M .. "/folder-bookmarks.svg") },
		{ L("Storage"),     env.fm .. " /mnt/storage", menu_icon("folder-bookmarks", M .. "/folder-bookmarks.svg") },
	}

	
	-- Main menu
	------------------------------------------------------------
	self.mainmenu = redflat.menu({ theme = theme,
		items = {
			{ L("Awesome"),       awesomemenu, menu_icon("awesome", M .. "/awesome.svg") },
			{ L("Applications"),  appmenu,     menu_icon("distributor-logo", M .. "/applications.svg") },
			{ L("Places"),        placesmenu,  menu_icon("folder_home", M .. "/folder-home.svg"), key = "c" },
			separator,
			{ L("Terminal"),      "guake", menu_icon("terminal", M .. "/terminal.svg") },
			{ L("Browser"),       "brave",  menu_icon("internet-web-browser", M .. "/browser.svg") },
			{ L("Nemo"),          "nemo",       menu_icon("folder", M .. "/file-manager.svg"), key = "n" },
			{ L("Editor"),        "geany",      menu_icon("emacs", M .. "/editor.svg") },
			separator,
			{ L("Exit"), function() redflat.float.oblogout:show() end, menu_icon("exit", M .. "/logout.svg") },
		}
	})

	-- Menu panel widget
	------------------------------------------------------------

	-- Sin recolor para asegurar visibilidad del icono izquierdo del panel.
	self.widget = redflat.gauge.svgbox(icon, nil, nil)
	self.buttons = awful.util.table.join(
		awful.button({ }, 1, function () self.mainmenu:toggle() end)
	)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return menu
