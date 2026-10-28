-----------------------------------------------------------------------------------------------------------------------
--                                              Autostart app list                                                   --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local autostart = {}

-- Lanza cmd solo si existe el binario y no hay ningún proceso con nombre pname.
-- pname puede ser nil → se extrae la primera palabra de cmd.
local function spawn_once(cmd, pname)
	pname = pname or cmd:match("^%S+"):match("([^/]+)$")
	awful.spawn.with_shell(string.format(
		'command -v "%s" > /dev/null 2>&1 && ! pgrep -x "%s" > /dev/null && ( %s )',
		pname, pname, cmd
	))
end

-- Application list function
--------------------------------------------------------------------------------
function autostart.run()
	-- utils (solo apps instaladas)
	spawn_once("nm-applet")
	spawn_once("blueman-applet")
    spawn_once("lxsession")
	-- Compositor: picom para transparencias, sombras y fade.
	spawn_once([[picom --config /dev/null --backend glx --vsync --fading --shadow --shadow-radius 7 --shadow-offset-x -7 --shadow-offset-y -7 --shadow-exclude "window_type = 'desktop' || window_type = 'dock'"]], "picom")

	-- Daemon de notificaciones: dunst (ligero, configurable).
	spawn_once("dunst")

	-- Screen locker: xsecurelock con auto-bloqueo tras 10 min de inactividad.
	-- xss-lock escucha los eventos idle de X11 y systemd-logind (suspend/lid).
	-- Si xss-lock no está instalado, usa xautolock como fallback.
	spawn_once(
		[[xss-lock -n /usr/lib/xsecurelock/dimmer -l -- sh -c 'XSECURELOCK_AUTH=auth_x11 XSECURELOCK_AUTHPROTO=authproto_pam XSECURELOCK_SAVER=dimmer XSECURELOCK_DIM_TIME=2 XSECURELOCK_DIM_COLOR="#1a1a1a" xsecurelock']],
		"xss-lock"
	)

	-- scripts de entorno opcionales (solo si existen, no fallan si no están)
	awful.spawn.with_shell("test -x ~/scripts/env/pa-setup.py && python ~/scripts/env/pa-setup.py || true")
	awful.spawn.with_shell("test -x ~/scripts/env/color-profile-setup.py && python ~/scripts/env/color-profile-setup.py || true")
	awful.spawn.with_shell("test -x ~/scripts/env/kbd-setup.py && python ~/scripts/env/kbd-setup.py || true")
	awful.spawn.with_shell("test -x ~/scripts/firefox/ff-sync.py && python ~/scripts/firefox/ff-sync.py || true")
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return autostart
