-----------------------------------------------------------------------------------------------------------------------
--                                    Qubes OS 4.3 bridge (borders + app menu)                                       --
-----------------------------------------------------------------------------------------------------------------------
-- Colorea bordes/titlebars según _QUBES_LABEL_COLOR de cada ventana y construye un
-- menú de Qubes (qubes-app-menu + apps por dominio). Compatible con Qubes 4.3.
-- Basado en /usr/share/awesome/lib/qubes.lua de qubes-desktop-linux-awesome.
-----------------------------------------------------------------------------------------------------------------------

local gears   = require("gears")
local gcolor  = require("gears.color")
local gstring = require("gears.string")
local beautiful = require("beautiful")

local qubes = {
	-- Prefijo "[vmname] " en el título de la ventana (como el Awesome oficial de Qubes)
	prefix_titles = true,
}

-- Labels clásicos (fallback si no hay _QUBES_LABEL_COLOR)
local LABEL_FALLBACK = {
	["1"] = "#cc0000", -- red
	["2"] = "#f57900", -- orange
	["3"] = "#edd400", -- yellow
	["4"] = "#73d216", -- green
	["5"] = "#555753", -- gray
	["6"] = "#3465a4", -- blue
	["7"] = "#75507b", -- purple
	["8"] = "#000000", -- black
	["*"] = "#333333", -- dom0 / unknown
}

local _detected -- nil = no comprobado aún

local function pread(cmd)
	local f = io.popen(cmd, "r")
	if not f then
		return ""
	end
	local data = f:read("*all") or ""
	f:close()
	return data
end

local function file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function dir_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	-- open puede fallar en directorios; probar con ls
	local out = pread("test -d " .. string.format("%q", path) .. " && echo ok")
	return out:match("ok") ~= nil
end

--- ¿Estamos en Qubes (dom0 / guivm)?
function qubes.available()
	if _detected ~= nil then
		return _detected
	end
	_detected = file_exists("/etc/qubes-release")
		or dir_exists("/var/lib/qubes")
		or file_exists("/usr/bin/qvm-ls")
	return _detected
end

-- ── Color helpers (de qubes.lua oficial) ──────────────────────────────────────

local function rgb_to_hls(r, g, b)
	local maxc = math.max(r, g, b)
	local minc = math.min(r, g, b)
	local l = (minc + maxc) / 2.0
	if minc == maxc then
		return 0.0, l, 0.0
	end
	local s
	if l <= 0.5 then
		s = (maxc - minc) / (maxc + minc)
	else
		s = (maxc - minc) / (2.0 - maxc - minc)
	end
	local rc = (maxc - r) / (maxc - minc)
	local gc = (maxc - g) / (maxc - minc)
	local bc = (maxc - b) / (maxc - minc)
	local h
	if r == maxc then
		h = bc - gc
	elseif g == maxc then
		h = 2.0 + rc - bc
	else
		h = 4.0 + gc - rc
	end
	h = (h / 6.0) % 1.0
	return h, l, s
end

local function v(m1, m2, hue)
	hue = hue % 1.0
	if hue < 1 / 6 then
		return m1 + (m2 - m1) * hue * 6.0
	end
	if hue < 0.5 then
		return m2
	end
	if hue < 2 / 3 then
		return m1 + (m2 - m1) * (2 / 3 - hue) * 6.0
	end
	return m1
end

local function hls_to_rgb(h, l, s)
	if s == 0.0 then
		return l, l, l
	end
	local m2
	if l <= 0.5 then
		m2 = l * (1.0 + s)
	else
		m2 = l + s - (l * s)
	end
	local m1 = 2.0 * l - m2
	return v(m1, m2, h + 1 / 3), v(m1, m2, h), v(m1, m2, h - 1 / 3)
end

local function ensure_min_luminance(colour, min_luminance)
	local r, g, b = gcolor.parse_color(colour)
	local h, l, s = rgb_to_hls(r, g, b)
	l = math.max(l, min_luminance)
	r, g, b = hls_to_rgb(h, l, s)
	return string.format("#%02x%02x%02x",
		math.floor(r * 0xff), math.floor(g * 0xff), math.floor(b * 0xff))
end

local function shift_luminance(colour, factor)
	local r, g, b = gcolor.parse_color(colour)
	local h, l, s = rgb_to_hls(r, g, b)
	l = math.max(math.min(l * factor, 1), 0)
	r, g, b = hls_to_rgb(h, l, s)
	return string.format("#%02x%02x%02x",
		math.floor(r * 0xff), math.floor(g * 0xff), math.floor(b * 0xff))
end

local function color_dec2hex(dec_color, default)
	if dec_color == nil or dec_color == "" then
		return default
	end
	return string.format("#%06x", tonumber(dec_color) or 0)
end

-- ── Ventanas: color por VM ────────────────────────────────────────────────────

function qubes.manage(c)
	if not c or not c.window then
		return
	end

	local data = pread(string.format(
		"xprop -id %s -notype _QUBES_VMNAME _QUBES_LABEL _QUBES_LABEL_COLOR 2>/dev/null",
		tostring(c.window)
	))

	c.qubes_vmname = string.match(data, '_QUBES_VMNAME = "(.+)"') or "dom0"
	c.qubes_label = string.match(data, "_QUBES_LABEL = (%d+)") or "*"

	local qcolor = color_dec2hex(string.match(data, "_QUBES_LABEL_COLOR = (%d+)"), nil)
	if not qcolor then
		qcolor = LABEL_FALLBACK[c.qubes_label] or LABEL_FALLBACK["*"]
	end
	c.qubes_label_color = qcolor
	c.qubes_prefix = "[" .. c.qubes_vmname .. "] "

	local qcolor_focus = ensure_min_luminance(qcolor, 0.3)
	c.qubes_label_color_focus = qcolor_focus
	c.qubes_label_color_unfocus = shift_luminance(qcolor_focus, 0.6)

	qubes.set_border_colour(c)
	if qubes.prefix_titles then
		qubes.set_name(c)
	end
end

function qubes.get_colour(c)
	if not c.qubes_label_color_unfocus then
		qubes.manage(c)
	end
	return c.qubes_label_color_unfocus
end

function qubes.get_colour_focus(c)
	if not c.qubes_label_color_focus then
		qubes.manage(c)
	end
	return c.qubes_label_color_focus
end

function qubes.set_border_colour(c)
	if not c or not c.valid then
		return
	end
	local focused = client.focus
	if (not focused) or (c == focused) then
		c.border_color = qubes.get_colour_focus(c)
	else
		c.border_color = qubes.get_colour(c)
	end
end

function qubes.set_name(c)
	if not c.qubes_prefix then
		qubes.manage(c)
	end
	local name = c.name or ""
	if not gstring.startswith(name, c.qubes_prefix) then
		c.name = c.qubes_prefix .. name
	end
end

--- Actualiza el fondo del titlebar redflat al color de la VM
function qubes.set_titlebar_colour(c)
	local ok, redtitle = pcall(require, "redflat.titlebar")
	if not ok or not redtitle.get_model then
		return
	end
	local model = redtitle.get_model(c, "top")
	if not model or not model.drawable then
		return
	end
	local focused = client.focus == c
	local col = focused and qubes.get_colour_focus(c) or qubes.get_colour(c)
	model.drawable:set_bg(col)
end

--- Color activo (focus) o atenuado para widgets del titlebar
function qubes.client_accent(c, focused)
	if focused == nil then
		focused = (client.focus == c)
	end
	if focused then
		return qubes.get_colour_focus(c)
	end
	return qubes.get_colour(c)
end

-- ── Systray Qubes (mismos applets que XFCE Session and Startup) ───────────────

-- Widgets oficiales de /etc/xdg/autostart en Qubes 4.3
local TRAY_WIDGETS = {
	"qui-domains",
	"qui-devices",
	"qui-clipboard",
	"qui-disk-space",
	"qui-updates",
}

local function desktop_exec(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local exec
	for line in f:lines() do
		local v = line:match("^Exec%s*=%s*(.+)$")
		if v then
			exec = v
			break
		end
	end
	f:close()
	return exec
end

--- Arranca los iconos de bandeja de Qubes (domains, devices, clipboard, disk, updates)
function qubes.start_systray_widgets()
	if not qubes.available() then
		return false
	end

	local awful = require("awful")
	local function run(cmd)
		if cmd and cmd ~= "" then
			awful.spawn.with_shell("(" .. cmd .. ") >/dev/null 2>&1 &")
		end
	end

	-- 1) Vía systemd user (Qubes 4.2+/4.3) — igual que los .desktop de XFCE
	for _, name in ipairs(TRAY_WIDGETS) do
		run("systemctl --user start qubes-widget@" .. name)
	end

	-- 2) Exec de /etc/xdg/autostart (misma fuente que “Session and Startup”)
	local adir = "/etc/xdg/autostart"
	local names = pread("ls -1 " .. string.format("%q", adir) .. " 2>/dev/null")
	for fname in names:gmatch("[^\r\n]+") do
		if fname:match("^qui%-") or fname == "qubes-device-agent.desktop" then
			run(desktop_exec(adir .. "/" .. fname))
		end
	end

	-- 3) Fallbacks por binario
	for _, name in ipairs(TRAY_WIDGETS) do
		if file_exists("/usr/bin/" .. name) then
			run("pgrep -f " .. string.format("%q", name) .. " >/dev/null || " .. name)
		end
	end

	-- Notificaciones XFCE (habituales en Qubes)
	if file_exists("/usr/lib/xfce4/notifyd/xfce4-notifyd") then
		run("pgrep -x xfce4-notifyd >/dev/null || /usr/lib/xfce4/notifyd/xfce4-notifyd")
	elseif file_exists("/usr/libexec/xfce4/notifyd/xfce4-notifyd") then
		run("pgrep -x xfce4-notifyd >/dev/null || /usr/libexec/xfce4/notifyd/xfce4-notifyd")
	end

	return true
end

-- ── Señales Awesome ───────────────────────────────────────────────────────────

function qubes.connect_signals()
	if not qubes.available() then
		return false
	end

	client.connect_signal("manage", function(c)
		qubes.manage(c)
	end)

	client.connect_signal("focus", function(c)
		c.border_color = qubes.get_colour_focus(c)
		qubes.set_titlebar_colour(c)
	end)

	client.connect_signal("unfocus", function(c)
		c.border_color = qubes.get_colour(c)
		qubes.set_titlebar_colour(c)
	end)

	client.connect_signal("property::name", function(c)
		if qubes.prefix_titles and c.qubes_prefix then
			qubes.set_name(c)
		end
	end)

	-- Titlebars creados después de manage
	client.connect_signal("request::titlebars", function(c)
		gears.timer.delayed_call(function()
			if c.valid then
				qubes.set_titlebar_colour(c)
			end
		end)
	end)

	return true
end

-- ── Menú de aplicaciones por qube ─────────────────────────────────────────────

local function parse_desktop(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local name, exec, icon, hidden, nodisplay
	for line in f:lines() do
		local k, v = line:match("^([%w%-]+)%s*=%s*(.*)$")
		if k == "Name" and not name then
			name = v
		elseif k == "Exec" and not exec then
			exec = v
		elseif k == "Icon" and not icon then
			icon = v
		elseif k == "Hidden" and v:lower() == "true" then
			hidden = true
		elseif k == "NoDisplay" and v:lower() == "true" then
			nodisplay = true
		end
	end
	f:close()
	if hidden or nodisplay or not name or not exec then
		return nil
	end
	exec = exec:gsub("%%[fFuUdDnNickvm]", ""):gsub("%s+$", "")
	return { name = name, exec = exec, icon = icon }
end

local function list_dir(path)
	local out = pread("ls -1 " .. string.format("%q", path) .. " 2>/dev/null")
	local names = {}
	for line in out:gmatch("[^\r\n]+") do
		if line ~= "" and line ~= "." and line ~= ".." then
			names[#names + 1] = line
		end
	end
	table.sort(names)
	return names
end

local LABEL_BY_NAME = {
	red = "#cc0000", orange = "#f57900", yellow = "#edd400",
	green = "#73d216", gray = "#555753", grey = "#555753",
	blue = "#3465a4", purple = "#75507b", black = "#000000",
}

local function label_to_hex(label)
	if not label or label == "" then
		return LABEL_FALLBACK["*"]
	end
	label = tostring(label):lower():gsub("%s+", "")
	if label:match("^#%x%x%x%x%x%x$") then
		return label
	end
	return LABEL_BY_NAME[label] or LABEL_FALLBACK["*"]
end

local function vm_label_color(vmname)
	local out = pread("qvm-prefs --get " .. string.format("%q", vmname) .. " label 2>/dev/null")
	return label_to_hex(out:match("(%S+)"))
end

-- Icono SVG sólido del color del label (cache en ~/.cache/awesome/qubes-labels)
local function label_icon(hex)
	hex = (hex or "#333333"):lower()
	if not hex:match("^#%x%x%x%x%x%x$") then
		hex = "#333333"
	end
	local cache = (os.getenv("HOME") or "/tmp") .. "/.cache/awesome/qubes-labels"
	pread("mkdir -p " .. string.format("%q", cache))
	local path = cache .. "/" .. hex:sub(2) .. ".svg"
	if not file_exists(path) then
		local f = io.open(path, "w")
		if f then
			f:write(string.format(
				'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
				.. '<rect width="16" height="16" rx="3" fill="%s"/></svg>\n',
				hex
			))
			f:close()
		end
	end
	return path
end

local function sh_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function build_vm_apps(vmname, color)
	local home = os.getenv("HOME") or ""
	local apps_dir = home .. "/.local/share/qubes-appmenus/" .. vmname .. "/apps"
	local items = {}
	local qvm = sh_quote(vmname)
	local icon = label_icon(color)
	local item_theme = {
		color = {
			left_icon = color,
			submenu_icon = color,
		},
	}

	if dir_exists(apps_dir) then
		for _, fname in ipairs(list_dir(apps_dir)) do
			if fname:match("%.desktop$") then
				local entry = parse_desktop(apps_dir .. "/" .. fname)
				if entry then
					items[#items + 1] = {
						entry.name,
						entry.exec,
						entry.icon or icon,
						theme = item_theme,
					}
				end
			end
		end
	end

	items[#items + 1] = {
		"Terminal: " .. vmname,
		"qvm-run -q -a " .. qvm .. " -- xfce4-terminal",
		icon,
		theme = item_theme,
	}
	items[#items + 1] = {
		"Start: " .. vmname,
		"qvm-start --skip-if-running " .. qvm,
		icon,
		theme = item_theme,
	}
	items[#items + 1] = {
		"Shutdown: " .. vmname,
		"qvm-shutdown --wait " .. qvm,
		icon,
		theme = item_theme,
	}
	items[#items + 1] = {
		"Settings: " .. vmname,
		"qubes-vm-settings " .. qvm,
		icon,
		theme = item_theme,
	}

	return items
end

-- Lista de VMs: name, class, label, service?, disp_template?
local function list_qubes()
	local vms = {}

	-- Preferible: API Python de Qubes 4.3
	local py = pread([[python3 -c '
import sys
try:
    import qubesadmin
    app = qubesadmin.Qubes()
    for vm in sorted(app.domains, key=lambda v: v.name):
        if vm.name == "dom0":
            continue
        klass = getattr(vm, "klass", type(vm).__name__)
        try:
            label = vm.label.name
        except Exception:
            label = "black"
        service = 1 if vm.features.get("servicevm", False) else 0
        disp = 0
        try:
            disp = 1 if getattr(vm, "template_for_dispvms", False) else 0
        except Exception:
            pass
        print("%s\t%s\t%s\t%d\t%d" % (vm.name, klass, label, service, disp))
except Exception as e:
    sys.stderr.write(str(e))
    sys.exit(1)
' 2>/dev/null]])

	if py ~= "" and not py:match("^Traceback") then
		for line in py:gmatch("[^\r\n]+") do
			local name, klass, label, service, disp = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(%d)\t(%d)$")
			if name then
				vms[#vms + 1] = {
					name = name,
					klass = klass,
					color = label_to_hex(label),
					service = service == "1",
					disp_template = disp == "1",
				}
			end
		end
		if #vms > 0 then
			return vms
		end
	end

	-- Fallback: qvm-ls
	local ls = pread("qvm-ls --raw-data --fields=name,class,label 2>/dev/null")
	for line in ls:gmatch("[^\r\n]+") do
		local name, klass, label = line:match("^([^|]+)|([^|]+)|([^|]+)$")
		if not name then
			name, klass, label = line:match("^(%S+)%s+(%S+)%s+(%S+)$")
		end
		if name and name ~= "dom0" and name ~= "NAME" then
			local lname = name:lower()
			local is_service = lname:match("^sys%-") or lname:match("^vpn%-")
			vms[#vms + 1] = {
				name = name,
				klass = klass or "AppVM",
				color = label_to_hex(label),
				service = not not is_service,
				disp_template = false,
			}
		end
	end

	-- Último recurso: carpetas de appmenus
	if #vms == 0 then
		local home = os.getenv("HOME") or ""
		local root = home .. "/.local/share/qubes-appmenus"
		if dir_exists(root) then
			for _, vm in ipairs(list_dir(root)) do
				if not vm:match("^%.") then
					vms[#vms + 1] = {
						name = vm,
						klass = "AppVM",
						color = vm_label_color(vm),
						service = not not vm:match("^sys%-"),
						disp_template = false,
					}
				end
			end
		end
	end

	return vms
end

local function classify_vm(vm)
	local klass = (vm.klass or ""):lower()
	if klass:match("template") or vm.disp_template then
		return "templates"
	end
	if vm.service or klass:match("netvm") or klass:match("proxy") then
		return "services"
	end
	-- DispVM en ejecución → Apps; AdminVM se ignora arriba
	return "apps"
end

local function vm_menu_entry(vm)
	local color = vm.color or LABEL_FALLBACK["*"]
	local icon = label_icon(color)
	return {
		vm.name,
		build_vm_apps(vm.name, color),
		icon,
		theme = {
			color = {
				left_icon = color,
				submenu_icon = color,
				main = color, -- resalte al pasar el ratón = color del qube
			},
		},
	}
end

--- Menú Qubes 4.3: Apps / Templates / Services (con color de label)
-- @param L function traductor
-- @param menu_icon function(name, fallback) → path
function qubes.menu_items(L, menu_icon)
	L = L or function(s) return s end
	menu_icon = menu_icon or function(_, fb) return fb end

	local qubes_logo = "/usr/share/icons/hicolor/16x16/apps/qubes-logo-icon.png"
	if not file_exists(qubes_logo) then
		qubes_logo = "/usr/share/icons/hicolor/24x24/apps/qubes-logo-icon.png"
	end
	if not file_exists(qubes_logo) then
		qubes_logo = menu_icon("applications", nil)
	end

	local items = {}

	if file_exists("/usr/bin/qubes-app-menu") then
		items[#items + 1] = {
			L("Application menu"),
			"qubes-app-menu",
			qubes_logo,
		}
	end

	local groups = {
		apps = {},
		templates = {},
		services = {},
	}

	for _, vm in ipairs(list_qubes()) do
		local bucket = classify_vm(vm)
		groups[bucket][#groups[bucket] + 1] = vm_menu_entry(vm)
	end

	local order = {
		{ key = "apps",      title = L("Apps") },
		{ key = "templates", title = L("Templates") },
		{ key = "services",  title = L("Services") },
	}

	for _, g in ipairs(order) do
		local list = groups[g.key]
		if #list > 0 then
			items[#items + 1] = {
				g.title,
				list,
				qubes_logo,
			}
		end
	end

	local tools = {}
	local tool_cmds = {
		{ L("Qube Manager"), "qubes-qube-manager" },
		{ L("Global Config"), "qubes-global-config" },
		{ L("Policy editor"), "qubes-policy-editor" },
		{ L("Backup"), "qubes-backup" },
		{ L("Restore backup"), "qubes-backup-restore" },
	}
	for _, t in ipairs(tool_cmds) do
		local bin = t[2]:match("^(%S+)")
		if file_exists("/usr/bin/" .. bin) then
			tools[#tools + 1] = { t[1], t[2], qubes_logo }
		end
	end
	if #tools > 0 then
		items[#items + 1] = { L("Tools"), tools, qubes_logo }
	end

	if #items == 0 then
		items[#items + 1] = {
			L("Qubes not detected"),
			function() end,
			qubes_logo,
		}
	end

	return items, qubes_logo
end

return qubes
