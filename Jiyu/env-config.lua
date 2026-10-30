------------------------------------------------------------------------------------------------------------------------
--                                                  Environment config                                               --
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local wibox = require("wibox")
local naughty = require("naughty")

local redflat = require("redflat")

local unpack = unpack or table.unpack

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local env = {}

-- Build hotkeys depended on config parameters
-----------------------------------------------------------------------------------------------------------------------
function env:init(args)

	-- init vars
	args = args or {}

	-- Idioma UI (es/en): "auto" según LANG, o "es" / "en" fijo
	local locale_mod = require("Jiyu.locale")
	locale_mod.init({ locale = args.locale })
	self.locale = locale_mod.get_lang()
	local L = locale_mod.t

	-- environment vars (por defecto JiyuLight: si quedara "red" cargaría otro directorio y parecería que "no carga el tema")
	self.theme = args.theme or "JiyuLight"
	self.terminal = args.terminal or os.getenv("TERMINAL") or "alacritty"
	self.browser  = args.browser  or os.getenv("BROWSER")  or "librewolf"
	-- Configuración de monitores (RandR): por defecto arandr; puedes usar "wdisplays" o una orden xrandr.
	self.display_config = args.display_config or "arandr"
	-- Opcional: menú Bluetooth del panel abre este gestor (p. ej. "blueman-manager", "blueberry").
	self.bluetooth_manager = args.bluetooth_manager
	self.mod    = args.mod    or "Mod4"
	self.fm     = args.fm     or os.getenv("FILE_MANAGER") or "nemo"
	self.mail   = args.mail   or os.getenv("MAIL_CLIENT")  or "thunderbird"
	self.player = args.player or os.getenv("MUSIC_PLAYER") or "pragha"
	self.updates = args.updates or
		[[bash -c "pacman -Qu 2>/dev/null | wc -l"]]
	self.home = os.getenv("HOME")
	self.themedir = awful.util.get_configuration_dir() .. "themes/" .. self.theme

	-- boolean defaults is pain
	self.sloppy_focus = args.sloppy_focus or false
	self.color_border_focus = args.color_border_focus or false
	self.set_slave = (args.set_slave == nil) and true or args.set_slave
	self.set_center = args.set_center or false
	self.desktop_autohide = args.desktop_autohide or false

	-- theme setup (beautiful.init usa dofile; si falla o devuelve tabla vacía, Awesome queda casi sin estilo)
	local themepath = self.themedir .. "/theme.lua"
	local fallback = "/usr/share/awesome/themes/default/theme.lua"

	-- theme.lua hace require("themes.Jiyu.base-colored"): hace falta ~/.config/awesome/?.lua en package.path.
	-- Si falta, el require falla, protected_call oculta el error y beautiful.init devuelve false → tema por defecto.
	local confdir = awful.util.get_configuration_dir()
	if confdir and confdir ~= "" then
		package.path = confdir .. "?.lua;" .. confdir .. "?/init.lua;" .. package.path
	end

	local function mensaje_fallo_tema(path)
		local ok_dof, res = pcall(dofile, path)
		if not ok_dof then
			return tostring(res)
		end
		if type(res) ~= "table" or not next(res) then
			return L("theme.lua did not return a valid data table (empty or nil).")
		end
		return L("Unknown failure (if theme loads in pcall, check Awesome stderr).")
	end

	if not gears.filesystem.file_readable(themepath) then
		naughty.notify({
			preset = naughty.config.presets.critical,
			title = L("Jiyu theme"),
			text = L("Theme file does not exist or is not readable:")
				.. "\n" .. themepath .. "\n"
				.. L("Check theme= in rc-Jiyu and env:init."),
			timeout = 0,
		})
	end

	local ok = beautiful.init(themepath)
	if not ok and gears.filesystem.file_readable(fallback) then
		local detalle = mensaje_fallo_tema(themepath)
		naughty.notify({
			preset = naughty.config.presets.critical,
			title = L("Jiyu theme"),
			text = L("Could not load Jiyu theme. Falling back to Awesome default theme.") .. "\n\n"
				.. detalle,
			timeout = 0,
		})
		ok = beautiful.init(fallback)
	elseif not ok then
		naughty.notify({
			preset = naughty.config.presets.critical,
			title = L("Theme"),
			text = L("beautiful.init failed and no fallback exists at")
				.. " " .. fallback .. "\n\n" .. mensaje_fallo_tema(themepath),
			timeout = 0,
		})
	end

	-- Tras init: tablas de fuente { font=, size= } → string para beautiful.get_font (textbox:set_font, etc.)
	require("redflat.util.beautiful_font_safe")()

	-- Sin bg/fg/font muchos wibox y textos quedan en valores por defecto de Awesome (parece "sin tema").
	local patched = false
	if not beautiful.font then
		beautiful.font = (beautiful.fonts and beautiful.fonts.main) or "Lato 12"
		patched = true
	end
	if not beautiful.bg_normal then
		beautiful.bg_normal = (beautiful.color and beautiful.color.wibox) or "#d0d0d0"
		patched = true
	end
	if not beautiful.fg_normal then
		beautiful.fg_normal = (beautiful.color and beautiful.color.text) or "#000000"
		patched = true
	end
	if patched then
		naughty.notify({
			preset = naughty.config.presets.low,
			title = L("Theme"),
			text = L("Filled default bg_normal/fg_normal/font because theme did not expose them.")
				.. "\n" .. L("Theme path:") .. " " .. tostring(themepath),
			timeout = 10,
		})
	end

	-- naughty config
	naughty.config.padding = beautiful.useless_gap and 2 * beautiful.useless_gap or 0

	-- Igual que service.logout: no asumir que existen base/normal/… (evita indexar nil).
	if beautiful.naughty and beautiful.naughty.base then
		local n = beautiful.naughty
		naughty.config.presets.normal   = redflat.util.table.merge(n.base, n.normal or {})
		naughty.config.presets.critical = redflat.util.table.merge(n.base, n.critical or {})
		naughty.config.presets.low      = redflat.util.table.merge(n.base, n.low or {})
	end
end


-- Common functions
-----------------------------------------------------------------------------------------------------------------------

-- Wallpaper setup
--------------------------------------------------------------------------------
env.wallpaper = function(s)
	-- Si la rotación está activa, usa su imagen actual (Mod4+w la controla)
	local ok, wr = pcall(require, "Jiyu.wallpaper-rotate")
	if ok and wr.active and wr.current then
		gears.wallpaper.maximized(wr.current, s, false)
		return
	end
	-- Usa el wallpaper definido por el tema (wallpaper-dark/-light.png);
	-- si no es una imagen legible, cae al color de fondo.
	local wp = beautiful.wallpaper
	if type(wp) == "string" and gears.filesystem.file_readable(wp) then
		gears.wallpaper.maximized(wp, s, false)
	elseif beautiful.color and beautiful.color.bg then
		gears.wallpaper.set(beautiful.color.bg)
	end
end

-- Tag tooltip text generation
--------------------------------------------------------------------------------
env.tagtip = function(t)
	local layname = awful.layout.getname(awful.tag.getproperty(t, "layout"))
	if redflat.util.table.check(beautiful, "widget.layoutbox.name_alias") then
		layname = beautiful.widget.layoutbox.name_alias[layname] or layname
	end
	local L = require("Jiyu.locale").t
	return string.format(L("tag_tip_format"), t.name, #(t:clients()), layname)
end

-- Panel widgets wrapper
--------------------------------------------------------------------------------
env.wrapper = function(widget, name, buttons)
	local margin = redflat.util.table.check(beautiful, "widget.wrapper")
	               and beautiful.widget.wrapper[name] or { 0, 0, 0, 0 }
	local inner = widget
	if buttons then
		-- Capa con fondo casi transparente: el hit-test cubre todo el hueco del
		-- wrapper (márgenes + icono). Sin esto, algunos hijos SVG/medidor no
		-- propagan bien el clic al :buttons del gauge.
		local hit = wibox.container.background(widget)
		hit.bg = gears.color.create_pattern("#00000001")
		hit:buttons(buttons)
		inner = hit
	end

	return wibox.container.margin(inner, unpack(margin))
end


-- End
-----------------------------------------------------------------------------------------------------------------------
return env
