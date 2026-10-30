-----------------------------------------------------------------------------------------------------------------------
-- tests/theme_load.lua — carga los temas Jiyu / JiyuLight con stubs de awful/gears
-- y verifica invariantes clave (regresiones de la auditoría).
--
-- Uso: lua tests/theme_load.lua [raíz_del_config]   (cwd = raíz si no se pasa arg)
-----------------------------------------------------------------------------------------------------------------------
local ROOT = (arg and arg[1]) or "."
ROOT = ROOT:gsub("/+$", "")
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path

local function file_readable(p)
	local f = io.open(p, "r")
	if f then f:close(); return true end
	return false
end

-- ── Stubs ──────────────────────────────────────────────────────────────────────────
package.preload["awful"] = function()
	return {
		util = {
			get_configuration_dir = function() return ROOT .. "/" end,
			file_readable         = file_readable,
			table = {
				-- awful.util.table.clone: shallow (deep solo con 2º arg, que redflat no usa)
				clone = function(t, deep)
					local r = {}
					for k, v in pairs(t) do
						r[k] = (deep and type(v) == "table") and package.loaded.awful.util.table.clone(v, true) or v
					end
					return r
				end,
				join = function(...)
					local r = {}
					for _, t in ipairs({ ... }) do
						for k, v in pairs(t) do r[k] = v end
					end
					return r
				end,
			},
		},
		placement = setmetatable({}, { __index = function() return function() end end }),
		screen    = { focused = function() return nil end },
	}
end
package.preload["gears"] = function()
	return {
		shape      = setmetatable({}, { __index = function() return function() end end }),
		filesystem = {},
		timer      = {},
		wallpaper  = {},
	}
end
-- Gauges redflat: instanciados en init() — stub mínimo (el widget real necesita wibox).
for _, m in ipairs({ "redflat.gauge.graph.dash", "redflat.gauge.audio.blue" }) do
	package.preload[m] = function() return { new = function() return {} end } end
end

-- ── Aserciones ─────────────────────────────────────────────────────────────────────
local passed, failed = 0, 0
local function ok(cond, msg)
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		print("  FAIL: " .. msg)
	end
end
local function eq(got, want, msg)
	ok(got == want, string.format("%s (got %s, want %s)", msg, tostring(got), tostring(want)))
end

-- Los módulos themes.* comparten un único objeto cacheado (require): purgar entre cargas.
local function purge_themes()
	for name in pairs(package.loaded) do
		if name:match("^themes%.") then package.loaded[name] = nil end
	end
end

-- Recorre el tema y comprueba que todo string con pinta de ruta a un asset existe.
local function check_assets(t, name)
	local missing, seen = {}, {}
	local function walk(v)
		if type(v) == "table" then
			if seen[v] then return end
			seen[v] = true
			for _, sub in pairs(v) do walk(sub) end
		elseif type(v) == "string" and v:match("^/") and v:match("%.%a+$") then
			if not file_readable(v) then missing[#missing + 1] = v end
		end
	end
	walk(t)
	for _, p in ipairs(missing) do print("  asset ausente: " .. p) end
	eq(#missing, 0, name .. ": assets referenciados existen")
end

-- ── Tema oscuro ────────────────────────────────────────────────────────────────────
print("Jiyu (dark):")
purge_themes()
local dark = require("themes.Jiyu.theme")
eq(type(dark), "table", "devuelve tabla")
eq(dark.color.main, "#A30817", "color.main")
eq(dark.color.scheme, "dark", "color.scheme")
ok(dark.wallpaper and dark.wallpaper:match("wallpaper%-dark%.png$"), "wallpaper-dark.png")
ok(file_readable(dark.wallpaper), "wallpaper existe")
eq(dark.panel_height, 40, "panel_height")
-- naughty: presets heredados intactos (regresión histórica en JiyuLight)
ok(dark.naughty and dark.naughty.base and dark.naughty.normal and dark.naughty.low and dark.naughty.critical,
	"naughty.base/normal/low/critical existen")
-- layoutbox: menu heredado no pisado (width/auto_hotkey vienen de base)
eq(dark.widget.layoutbox.menu.width, 200, "layoutbox.menu.width")
eq(dark.widget.layoutbox.menu.auto_hotkey, true, "layoutbox.menu.auto_hotkey")
eq(dark.widget.layoutbox.panel_icon, dark.icon.awesome, "layoutbox panel_icon")
eq(dark.gauge.monitor.circle.width, 26, "monitor.circle.width")
eq(dark.gauge.audio.blue.color.off, "#3a3a3a", "audio off")
eq(dark.float.player.bottom_anchor_lift, 160, "float.player lift")
eq(type(dark.float.player.set_position), "function", "float.player.set_position")
eq(type(dark.float.pulsectl.set_position), "function", "pulsectl.set_position")
ok(dark.titlebar.icon.gray_until_hover, "titlebar gray_until_hover")
ok(dark.titlebar.icon.list.close:match("titlebar/close%.svg$"), "titlebar icon list")
ok(dark.float.winthumbs and dark.float.winthumbs.bg, "winthumbs preset")
ok(dark.widget.minitray.color and dark.widget.minitray.color.wibox, "minitray color")
eq(dark.desktop.playerbar.color.wibox, "#1a1a1ae8", "playerbar wibox")
check_assets(dark, "Jiyu")

-- ── Tema claro ─────────────────────────────────────────────────────────────────────
print("JiyuLight:")
purge_themes()
local light = require("themes.JiyuLight.theme")
eq(type(light), "table", "devuelve tabla")
eq(light.color.main, "#0066CC", "color.main")
eq(light.color.scheme, "light", "color.scheme")
eq(light.color.gray, "#666666", "color.gray (post-update)")
ok(light.wallpaper and light.wallpaper:match("wallpaper%-light%.png$"), "wallpaper-light.png")
ok(file_readable(light.wallpaper), "wallpaper existe")
-- regresión: naughty pisaba presets heredados
ok(light.naughty and light.naughty.base and light.naughty.normal and light.naughty.low and light.naughty.critical,
	"naughty presets heredados intactos")
eq(light.naughty.base.bg, "#d0d0d0f0", "naughty.base bg claro")
-- regresión: layoutbox.menu perdía width/auto_hotkey
eq(light.widget.layoutbox.menu.width, 200, "layoutbox.menu.width")
eq(light.widget.layoutbox.menu.auto_hotkey, true, "layoutbox.menu.auto_hotkey")
eq(light.gauge.audio.blue.color.off, "#c0c0c0", "audio off claro")
eq(light.float.top.action_button.color.button, "#d0d0d0", "top action button")
eq(light.widget.minitray.color.wibox, "#d0d0d0cc", "minitray blur")
eq(light.float.winthumbs.bg, "#d0d0d0f2", "winthumbs bg")
eq(light.notification_bg, "#d0d0d0f0", "notification_bg")
eq(light.desktop.playerbar.color.wibox, "#d0d0d0e8", "playerbar wibox")
eq(light.float.player.bottom_anchor_lift, 160, "float.player (nuevo en light)")
ok(light.titlebar.icon.gray_until_hover, "titlebar gray_until_hover (nuevo en light)")
check_assets(light, "JiyuLight")

print(string.format("\n%d OK, %d FAIL", passed, failed))
os.exit(failed == 0 and 0 or 1)
