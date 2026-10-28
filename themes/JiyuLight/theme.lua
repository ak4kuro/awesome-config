-----------------------------------------------------------------------------------------------------------------------
--                                                JiyuLight theme (white/blue)                                        --
--                                                                                                                   --
--  Solo define la paleta clara; toda la configuración de widgets/floats vive en                                      --
--  themes/Jiyu/shared.lua (apply(theme, pal)).                                                                      --
-----------------------------------------------------------------------------------------------------------------------
local awful = require("awful")

-- This theme was inherited from another with overwriting some values
-- Check parent theme to find full settings list and its description
local theme = require("themes.Jiyu.base-colored")

-- Common (usar theme.path de base-colored = themes/Jiyu; sin symlinks)
-----------------------------------------------------------------------------------------------------------------------

-- Color scheme (white/blue) — ANTES de update() para que init() los use
-----------------------------------------------------------------------------------------------------------------------
theme.color = {
	main      = "#0066CC",  -- Azul principal
	urgent    = "#E07800",  -- Naranja para urgencia
	scheme    = "light",    -- bandera canónica: "dark" | "light"
	gray      = "#666666",  -- Gris medio oscuro (visible sobre panel claro)
	bg        = "#d0d0d0",  -- Fondo blanco grisáceo claro
	bg_second = "#c8c8c8",  -- Fondo secundario gris claro
	wibox     = "#d0d0d0f0", -- Fondo semitransparente blanco grisáceo claro
	icon      = "#555555",  -- Iconos oscuros (visibles sobre panel claro)
	text      = "#000000",  -- Texto negro
	highlight = "#000000",  -- Resalte negro
	border    = "#b0b0b0",  -- Bordes gris medio
	muted     = "#666666",  -- Texto/iconos atenuados
	sep       = "#b8b8b8",  -- Separadores sutiles

	-- secondary colors
	shadow1   = "#c8c8c8",
	shadow2   = "#c8c8c8",
	shadow3   = "#d0d0d0",
	shadow4   = "#808080",

	button    = "#d0d0d0",
	pressed   = "#b0b0b0",

	desktop_gray = "#d0d0d0",
	desktop_icon = "#444444",
}

-- Main config
--------------------------------------------------------------------------------
theme.panel_height = 40
-- Degradado claro en la raíz del tema compartido (rc-Jiyu pinta el mismo fichero).
theme.wallpaper    = theme.path .. "/wallpaper-light.png"
theme.desktopbg    = nil

-- Setup parent theme settings (ahora con colores claros ya definidos)
--------------------------------------------------------------------------------
theme:update()


-- Paleta del tema claro (clave → literal que difiere respecto a Jiyu)
--------------------------------------------------------------------------------
local pal = {
	-- Popups / flotantes
	border        = "#b0b0b0",
	surface       = "#d0d0d0f0",
	surface_soft  = "#d0d0d0ee",
	surface_blur  = "#d0d0d0cc",           -- más transparente para blur
	popup_bg      = "#d0d0d0cc",
	popup_bg2     = "#c8c8c8cc",
	popup_icon    = "#555555",
	popup_gray    = "#666666",
	highlight     = "#000000",
	apprunner_bg2 = "#c8c8c8",

	-- Gauges del panel
	off           = "#c0c0c0",
	dash_gray     = "#808080",
	circle_gray   = "#c0c0c0",
	circle_icon   = "#555555",
	mic_off       = "#c0c0c0",
	sep_shadow1   = "#c0c0c0",
	sep_shadow2   = "#b8b8b8",

	-- Escritorio
	desk_gray     = "#444444",
	desk_gray2    = "#444444",
	player_wibox  = "#d0d0d0e8",
	player_muted  = "#666666",

	-- Hotkeys / tabla periódica
	hk_text       = "#000000",
	hk_gray       = "#b8b8b8",
	keycap_bg     = "#c8c8c8",
	keycap_fg     = "#000000",
	keycap_bg2    = "#c8c8c8",
	keycap_fg2    = "#000000",
	-- Segundo pase sobre hotkeys: fondo claro opaco como el resto de popups
	hk_forced = {
		wibox = "#d0d0d0f0", bg = "#d0d0d0", bg_second = "#c8c8c8",
		text = "#000000", gray = "#000000",
		keycap_bg = "#c8c8c8", keycap_fg = "#000000",
	},

	-- Interior de floats (netctl, brightctl, pulsectl, bluetooth)
	float_gray    = "#b8b8b8",
	muted         = "#666666",
	sep           = "#b8b8b8",
	float_bg      = "#d0d0d0",
	float_bg2     = "#c8c8c8",
	slider_track  = "#c8c8c8",

	-- Campo contraseña de netctl
	pwd_shadow3   = "#b8b8b8",
	pwd_shadow4   = "#666666",
	pwd_button    = "#b0b0b0",
	pwd_pressed   = "#b0b0b0",
	pwd_bg        = "#d0d0d0",
	pwd_shadow1   = "#b8b8b8",
	pwd_shadow2   = "#666666",

	-- Calendario flotante
	cal_gray      = "#b8b8b8",
	cal_wd_fg     = "#666666",
	cal_we_fg     = "#555555",
	cal_we_bg     = "#c8c8c8",
	cal_day_fg    = "#555555",
	cal_def_fg    = "#000000",

	-- Action buttons de top CPU/RAM (ab) y del popup top genérico (ab_top)
	ab      = { shadow3 = "#b8b8b8", button = "#b0b0b0", shadow4 = "#666666", text = "#000000", pressed = "#b0b0b0" },
	ab_top  = { shadow3 = "#c8c8c8", button = "#d0d0d0", shadow4 = "#b0b0b0", text = "#000000", pressed = "#b0b0b0" },

	-- Overrides sobre defaults oscuros del tema base
	menu_icon      = "#000000",
	tb_wibox       = "#d0d0d0f0",
	tasktip_gray   = "#000000",
	logout_icon    = "#666666",
	logout_gray    = "#b8b8b8",
	nav_mark       = "#b8b8b8",
	notify_icon    = "#666666",
	minitray_wibox = "#d0d0d0cc",
	win_bg         = "#d0d0d0f2",
	thumb_bg       = "#c8c8c8",
	thumb_bg_focus = "#b8b8b8",
	bt_icon        = "#555555",
	bt_gray        = "#666666",

	-- Overrides que el tema oscuro deja en heredado
	tag_gray       = "#808080",
	tag_icon       = "#555555",
	dots_gray      = "#808080",
	widget_icon    = "#555555",
}

require("themes.Jiyu.shared").apply(theme, pal)

-- End
-----------------------------------------------------------------------------------------------------------------------
return theme
