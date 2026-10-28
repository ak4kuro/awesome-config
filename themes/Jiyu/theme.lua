-----------------------------------------------------------------------------------------------------------------------
--                                                  Jiyu theme                                                       --
--                                                                                                                   --
--  Solo define la paleta oscura; toda la configuración de widgets/floats vive en                                    --
--  themes/Jiyu/shared.lua (apply(theme, pal)).                                                                      --
-----------------------------------------------------------------------------------------------------------------------
local awful = require("awful")

-- This theme was inherited from another with overwriting some values
-- Check parent theme to find full settings list and its description
local theme = require("themes.Jiyu.base-colored")


-- Color scheme
-----------------------------------------------------------------------------------------------------------------------
theme.color.main   = "#A30817"
theme.color.urgent = "#016B84"
theme.color.scheme = "dark"  -- bandera canónica: "dark" | "light"


-- Main config
--------------------------------------------------------------------------------
-- Altura suficiente para gauge.monitor.circle (28) + márgenes verticales del wrapper (~6–8px)
theme.panel_height = 40
-- Degradado oscuro en la raíz del tema (rc-Jiyu pinta el mismo fichero).
theme.wallpaper    = theme.path .. "/wallpaper-dark.png"
-- Solo si existe (evita rutas rotas en build.dynamic del escritorio).
local _deskbg = theme.path .. "/wallpaper/transparent.png"
theme.desktopbg    = awful.util.file_readable(_deskbg) and _deskbg or nil

-- Setup parent theme settings
-- theme:update() ejecuta theme:init() (base-colorless): gauge, service, widget por defecto.
-- shared.apply() refina después (grid escritorio, gauge.monitor.circle, wrapper panel, etc.).
--------------------------------------------------------------------------------
theme:update()


-- Paleta del tema oscuro (clave → literal que difiere respecto a JiyuLight)
-- Un campo ausente (nil) en shared.lua conserva el valor heredado del tema base.
--------------------------------------------------------------------------------
local pal = {
	-- Popups / flotantes
	border        = "#333333",
	surface       = "#1c1c1cf0",           -- fondo de popups y notificaciones
	surface_soft  = "#1a1a1aee",           -- tooltips
	surface_blur  = "#1c1c1cf0",           -- _popup_color.wibox / minitray
	popup_bg      = theme.color.bg,
	popup_bg2     = theme.color.bg_second,
	popup_icon    = theme.color.icon,
	popup_gray    = "#383838",
	highlight     = "#ffffff",
	apprunner_bg2 = "#1e1e1e",

	-- Gauges del panel
	off           = "#3a3a3a",             -- estado off de audio/brillo
	dash_gray     = "#3a3a3a",
	circle_gray   = theme.color.gray,
	circle_icon   = theme.color.icon,
	mic_off       = theme.color.gray,
	sep_shadow1   = "#3a3a3a",
	sep_shadow2   = "#2e2e2e",

	-- Escritorio
	desk_gray     = theme.color.gray,
	player_wibox  = "#1a1a1ae8",
	player_muted  = theme.color.icon,

	-- Hotkeys / tabla periódica
	hk_text       = "#888888",
	hk_gray       = "#444444",
	keycap_bg     = "#2e2e2e",
	keycap_fg     = "#e0e0e0",
	keycap_bg2    = "#242424",
	keycap_fg2    = "#e8e8e8",

	-- Interior de floats (netctl, brightctl, pulsectl, bluetooth)
	float_gray    = theme.color.gray,
	muted         = theme.color.icon,
	sep           = "#2e2e2e",
	float_bg      = theme.color.bg,
	float_bg2     = theme.color.bg_second,
	slider_track  = theme.color.bg_second,

	-- Campo contraseña de netctl
	pwd_shadow3   = theme.color.shadow1,
	pwd_shadow4   = theme.color.shadow2,
	pwd_button    = theme.color.gray,      -- = monitor.circle.color.gray
	pwd_pressed   = theme.color.bg_second,
	pwd_bg        = theme.color.bg,
	pwd_shadow1   = theme.color.shadow1,
	pwd_shadow2   = theme.color.shadow2,

	-- Calendario flotante
	cal_gray      = "#383838",
	cal_wd_fg     = "#555555",
	cal_we_fg     = "#aaaaaa",
	cal_we_bg     = "#252525",
	cal_day_fg    = "#aaaaaa",
	cal_def_fg    = "#cccccc",

	-- Action buttons de top CPU/RAM (ab) y del popup top genérico (ab_top)
	ab      = { shadow3 = "#1e1e1e", button = "#2e2e2e", shadow4 = "#3a3a3a", text = "#cccccc", pressed = "#252525" },
	ab_top  = { shadow3 = "#1e1e1e", button = "#2e2e2e", shadow4 = "#3a3a3a", text = "#cccccc", pressed = "#252525" },

	-- Overrides sobre defaults del tema base (antes implícitos)
	menu_icon      = theme.color.icon,
	tb_wibox       = theme.color.wibox,
	tasktip_gray   = theme.color.gray,
	logout_icon    = theme.color.icon,
	logout_gray    = theme.color.gray,
	nav_mark       = theme.color.gray,
	notify_icon    = theme.color.icon,
	minitray_wibox = "#1c1c1cf0",
	win_bg         = "#1c1c1cf2",
	thumb_bg       = "#181818",
	thumb_bg_focus = "#313131",
	bt_icon        = "#3a3a3a",
	bt_gray        = "#3a3a3a",

	-- nil → conservar heredado: tag_gray, tag_icon, dots_gray, widget_icon, desk_gray2, hk_forced
}

require("themes.Jiyu.shared").apply(theme, pal)

-- End
-----------------------------------------------------------------------------------------------------------------------
return theme
