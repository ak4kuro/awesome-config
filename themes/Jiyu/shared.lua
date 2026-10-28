-----------------------------------------------------------------------------------------------------------------------
--                          Configuración compartida de los temas Jiyu / JiyuLight                                    --
--                                                                                                                   --
--  apply(theme, pal) aplica TODOS los overrides comunes tras theme:update().                                        --
--  Los literales que difieren entre dark/light llegan por `pal` (definida en cada theme.lua).                      --
--  Un valor `nil` en pal equivale a "conservar el valor heredado" (el merge lo ignora).                             --
-----------------------------------------------------------------------------------------------------------------------
local awful   = require("awful")
local redutil = require("redflat.util")

local function apply(theme, pal)

	-- Icono del panel = mismo pack que el menú (icons/menu/awesome.svg)
	theme.icon.awesome = theme.path .. "/icons/menu/awesome.svg"
	-- Layoutbox (izquierda): icono fijo awesome.svg; el menú de layouts sigue usando los PNG por tipo.
	theme.widget.layoutbox.panel_icon = theme.icon.awesome
	if pal.widget_icon then
		theme.widget.layoutbox.color = redutil.table.merge(theme.widget.layoutbox.color or {}, {
			icon = pal.widget_icon,
		})
		theme.widget.layoutbox.menu = redutil.table.merge(theme.widget.layoutbox.menu or {}, {
			color = { right_icon = pal.widget_icon, left_icon = pal.widget_icon },
		})
	end

	-- Desktop config
	-------------------------------------------------------------------------------------------------------------------

	-- Desktop widgets placement
	--------------------------------------------------------------------------------
	-- Dos columnas × 8 filas; altura 56px para caber el multímetro CPU (barras por núcleo)
	local gh = {}
	for i = 1, 8 do
		gh[i] = 56
	end
	theme.desktop.grid = {
		width  = { 400, 400 },
		height = gh,
		edge   = { width = { 100, 100 }, height = { 72, 72 } }
	}

	-- Desktop widgets
	--------------------------------------------------------------------------------
	-- individual widget settings doesn't used by redflat module
	-- but grab directly from rc-files to rewrite base style
	theme.individual.desktop = { speedmeter = {}, multimeter = {}, multiline = {}, playerbar = {} }

	-- Barra inferior de escritorio: MPRIS (playerctl)
	theme.desktop.playerbar = redutil.table.merge(
		{
			margin    = { 12, 12, 8, 8 },
			timeout   = 1.2,
			titlefont = theme.fonts.hint,
			artistfont = theme.fonts.hint,
			timefont  = theme.fonts.hint,
			title_max = 64,
			artist_max = 48,
			bar_height = 4,
			buttons_gap = 8,
			cover_size = 54,
			cover_margin = { -3, 12, 0, 0 },
			color = {
				main  = theme.color.main,
				gray  = theme.color.gray,
				wibox = pal.player_wibox,
				text  = theme.color.text,
				muted = pal.player_muted,
				icon  = pal.player_muted,
			},
			icon = {
				cover = theme.path .. "/player/cover.svg",
				prev  = theme.path .. "/player/previous.svg",
				play  = theme.path .. "/player/play.svg",
				pause = theme.path .. "/player/pause.svg",
				next  = theme.path .. "/player/next.svg",
			},
			progressbar = { color = theme.color },
		},
		theme.individual.desktop.playerbar or {}
	)

	-- Una fila por widget con barra de progreso (segmentos) claramente visibles
	theme.desktop.common.pack.lines.line.height = 14
	theme.desktop.common.pack.lines.progressbar.chunk = { gap = 4, width = 8 }
	theme.desktop.common.pack.lines.tooltip.set_position = function(wibox)
		awful.placement.under_mouse(wibox)
		wibox.y = wibox.y - 30
	end

	-- Upright bar (common part)
	theme.desktop.common.bar.shaped.show.tooltip = true
	theme.desktop.common.bar.shaped.tooltip.set_position = theme.desktop.common.pack.lines.tooltip.set_position

	-- Sin fondo de “tarjeta” en widgets de escritorio (evita recuadros grises alrededor del contenido)
	theme.desktop.multiline.color = {
		main = theme.color.main,
		gray = pal.desk_gray,
		wibox = "#00000000",
	}
	theme.desktop.multimeter.color = {
		main = theme.color.main,
		gray = pal.desk_gray,
		wibox = "#00000000",
	}
	theme.desktop.speedmeter.compact.color = {
		main = theme.color.main,
		gray = pal.desk_gray,
		wibox = "#00000000",
	}
	if theme.desktop.color then
		theme.desktop.color.wibox = "#00000000"
		if pal.desk_gray2 then
			theme.desktop.color.gray = pal.desk_gray2
		end
	end

	-- Calendario del escritorio: mismo gris que el resto de widgets
	theme.desktop.calendar = redutil.table.merge(theme.desktop.calendar or {}, {
		color = {
			main  = theme.color.main,
			gray  = pal.desk_gray,
			wibox = "#00000000",
			bg    = "#00000000",
		},
	})

	-- Speedmeter (base widget)
	theme.desktop.speedmeter.compact.icon = {
		up = theme.path .. "/desktop/up.svg",
		down = theme.path .. "/desktop/down.svg",
		margin = { 0, 4, 0, 0}
	}
	theme.desktop.speedmeter.compact.height.chart = 40
	theme.desktop.speedmeter.compact.label.width = 76
	theme.desktop.speedmeter.compact.label.height = 15 -- manually set after font size
	theme.desktop.speedmeter.compact.label.font = { font = "Play", size = 22, face = 1, slant = 0 }
	theme.desktop.speedmeter.compact.margins.label = { 10, 10, 0, 0 }
	theme.desktop.speedmeter.compact.margins.chart = { 0, 0, 3, 3 }
	theme.desktop.speedmeter.compact.chart = { bar = { width = 6, gap = 3 }, height = nil, zero_height = 0 }
	theme.desktop.speedmeter.compact.progressbar = { chunk = { width = 6, gap = 3 }, height = 3 }

	-- Speedmeter drive (individual widget)
	theme.individual.desktop.speedmeter.drive = {
		unit   = { { "B", -1 }, { "KB", 2 }, { "MB", 2048 } },
	}

	-- Multimeter (base widget); num de segmentos lo ajusta desktop-config al número de núcleos
	theme.desktop.multimeter.upbar          = { width = 28, chunk = { num = 8, line = 4 }, shape = "plain" }
	theme.desktop.multimeter.lines.show     = { label = false, tooltip = true, text = false }
	theme.desktop.multimeter.icon.full      = false
	theme.desktop.multimeter.icon.margin    = { 0, 6, 0, 0 }
	theme.desktop.multimeter.height.upright = 48
	theme.desktop.multimeter.height.lines   = 0

	-- Multimeter CPU: barras verticales por núcleo (tooltip por core)
	theme.individual.desktop.multimeter.cpu = {
		icon   = { image = theme.path .. "/desktop/cpu.svg" },
		height = { upright = 48, lines = 0 },
		lines  = {
			margin = { 0, 0, 0, 0 },
			show   = { label = false, text = false, tooltip = true },
			line   = { height = 0 },
		},
	}

	-- Misma “fila” visual para todos los multiline (fuente, márgenes, barra)
	local desk_row_lines = {
		margin = { 0, 0, 4, 0 },
		-- Sin textos/etiquetas: solo icono + barra + tooltip.
		show   = { label = false, text = false, tooltip = true },
		line   = { height = 14 },
		text   = { font = { font = "Play", size = 13, face = 1, slant = 0 }, width = 220 },
		label  = { font = { font = "Play", size = 13, face = 1, slant = 0 }, width = 42 },
		gap    = { text = 6, label = 6 },
		progressbar = { chunk = { gap = 4, width = 8 } },
	}

	-- NET: dos filas (UP/DOWN); spacing evita que se solapen
	local netline_lines = {
		margin = desk_row_lines.margin,
		show = desk_row_lines.show,
		line = desk_row_lines.line,
		-- Para que UP/DOWN aprovechen mejor el ancho disponible:
		-- el bloque del valor (texto) y la etiqueta reservan menos ancho.
		text = { font = desk_row_lines.text.font, width = 180 },
		label = { font = desk_row_lines.label.font, width = 34 },
		gap = { text = 4, label = 4 },
		progressbar = desk_row_lines.progressbar,
		-- Separación un poco mayor entre UP y DOWN
		spacing = 8,
	}

	-- NET subida/bajada
	theme.individual.desktop.multiline.netline = {
		unit   = { { "B/s", -1 }, { "K/s", 1024 }, { "M/s", 1024^2 } },
		digits = 2,
		icon   = { image = theme.path .. "/desktop/down.svg", margin = { 0, 6, 0, 0 } },
		lines  = netline_lines,
	}

	-- RAM y swap
	theme.individual.desktop.multiline.ramone = {
		unit   = { { "MB", -1 }, { "GB", 1024 } },
		digits = 2,
		icon   = { image = theme.path .. "/desktop/storage.svg", margin = { 0, 6, 0, 0 } },
		-- RAM sin números (solo etiqueta/tooltip) para que la barra use más ancho
		lines  = {
			margin      = desk_row_lines.margin,
			show        = { label = desk_row_lines.show.label, text = false, tooltip = desk_row_lines.show.tooltip },
			line        = desk_row_lines.line,
			text        = desk_row_lines.text,
			label       = desk_row_lines.label,
			gap         = desk_row_lines.gap,
			progressbar = desk_row_lines.progressbar,
		},
	}

	theme.individual.desktop.multiline.swapone = {
		unit   = { { "MB", -1 }, { "GB", 1024 } },
		digits = 2,
		icon   = { image = theme.path .. "/desktop/storage.svg", margin = { 0, 6, 0, 0 } },
		-- Swap sin números (solo etiqueta/tooltip) para que la barra use más ancho
		lines  = {
			margin      = desk_row_lines.margin,
			show        = { label = desk_row_lines.show.label, text = false, tooltip = desk_row_lines.show.tooltip },
			line        = desk_row_lines.line,
			text        = desk_row_lines.text,
			label       = desk_row_lines.label,
			gap         = desk_row_lines.gap,
			progressbar = desk_row_lines.progressbar,
		},
	}

	-- root / home
	theme.individual.desktop.multiline.diskline = {
		unit   = { { "KB", 1 }, { "MB", 1024^1 }, { "GB", 1024^2 } },
		digits = 2,
		icon   = { image = theme.path .. "/desktop/storage.svg", margin = { 0, 6, 0, 0 } },
		-- Root/Home sin texto en línea.
		lines = {
			margin = desk_row_lines.margin,
			show = { label = false, text = false, tooltip = true },
			line = desk_row_lines.line,
			-- Valor más pequeño para que el texto (usado/total) quepa sin recortar.
			text = { font = { font = "Play", size = 13, face = 1, slant = 0 }, width = 200 },
			label = desk_row_lines.label,
			gap = { text = 4, label = desk_row_lines.gap.label },
			progressbar = desk_row_lines.progressbar,
		},
	}

	-- Multilines (base widget): etiqueta + texto visibles (filas uniformes)
	theme.desktop.multiline.lines.show     = { label = false, tooltip = true, text = false }
	theme.desktop.multiline.icon.margin    = theme.desktop.multimeter.icon.margin

	-- Multilines storage (legacy / otros temas)
	theme.individual.desktop.multiline.storage = {
		unit      = { { "KB", 1 }, { "MB", 1024^1 }, { "GB", 1024^2 } },
		icon      = { image = theme.path .. "/desktop/storage.svg" },
		lines     = {
			line        = { height = 10 },
			progressbar = { chunk = { gap = 6, width = 4 } },
		},
	}

	-- Multilines temperature (individual widget)
	theme.individual.desktop.multiline.thermal = {
		digits    = 1,
		icon      = { image = theme.path .. "/desktop/thermometer.svg", margin = { 0, 8, 0, 0 } },
		lines     = {
			line        = { height = 13 },
			text        = { font = { font = "Play", size = 18, face = 1, slant = 0 }, width = 44 },
			label       = { font = { font = "Play", size = 18, face = 1, slant = 0 } },
			gap         = { text = 10 },
			progressbar = { chunk = { gap = 6, width = 4 } },
			-- Sin números, para que la barra aproveche el ancho
			show        = { text = false, label = false, tooltip = true },
		},
		unit      = { { "°C", -1 } },
	}

	-- Temperaturas / GPU / PCH / ACPI (misma fila que el resto)
	theme.individual.desktop.multiline.thermal_one = {
		digits = 1,
		icon   = { image = theme.path .. "/desktop/thermometer.svg", margin = { 0, 6, 0, 0 } },
		lines  = {
			margin = desk_row_lines.margin,
			show   = { label = false, text = false, tooltip = true },
			line   = desk_row_lines.line,
			-- Más legible (especialmente cuando antes se ocultó el valor).
			text   = { font = { font = "Play", size = 16, face = 1, slant = 0 }, width = 200 },
			label  = desk_row_lines.label,
			gap    = { text = 4, label = desk_row_lines.gap.label },
			progressbar = desk_row_lines.progressbar,
		},
		unit   = { { "°C", -1 } },
	}

	-- Core (CPU): sin número para que la barra use todo el ancho disponible
	theme.individual.desktop.multiline.thermal_core = {
		digits = 1,
		icon   = { image = theme.path .. "/desktop/thermometer.svg", margin = { 0, 6, 0, 0 } },
		lines  = {
			margin      = desk_row_lines.margin,
			show        = { label = false, text = false, tooltip = true },
			line        = desk_row_lines.line,
			text        = desk_row_lines.text,
			label       = desk_row_lines.label,
			gap         = desk_row_lines.gap,
			progressbar = desk_row_lines.progressbar,
		},
		unit   = { { "°C", -1 } },
	}

	-- Ventilador
	theme.individual.desktop.multiline.fan = {
		digits = 1,
		margin = { 0, 0, 4, 4 },
		icon   = { image = theme.path .. "/desktop/fan.svg", margin = { 0, 6, 0, 0 } },
		lines  = desk_row_lines,
		unit   = { { "RPM", -1 } },
	}

	-- Batería (escritorio: sin texto/etiqueta; solo icono + barra + tooltip)
	theme.individual.desktop.multiline.laptop_sensors = {
		digits = 0,
		icon   = { image = theme.path .. "/widget/battery.svg", margin = { 0, 6, 0, 0 } },
		lines  = desk_row_lines,
		unit   = { { "%", -1 } },
	}

	-- vnstat
	theme.individual.desktop.multiline.vnstat = {
		digits = 3,
		margin = { 0, 0, 4, 4 },
		icon   = { image = theme.path .. "/desktop/traffic.svg", margin = { 0, 6, 0, 0 } },
		lines  = desk_row_lines,
		unit   = { { "B", 1 }, { "KiB", 1024 }, { "MiB", 1024^2 }, { "GiB", 1024^3 } },
	}

	-- Panel widgets
	-------------------------------------------------------------------------------------------------------------------

	-- individual margins for panel widgets
	------------------------------------------------------------
	theme.widget.wrapper = {
		layoutbox   = { 12, 9, 6, 6 },
		textclock   = { 10, 10, 0, 0 },
		-- Solo icono (pulsectl con sliders): márgenes ajustados
		volume      = { 4, 4, 3, 3 },
		microphone  = { 5, 6, 6, 6 },
		keyboard    = { 9, 9, 3, 3 },
		mail        = { 9, 9, 3, 3 },
		tray        = { 8, 8, 7, 7 },
		-- Márgenes verticales bajos (3–4) para no recortar los círculos con panel_height 40
		cpu         = { 6, 2, 3, 3 },
		ram         = { 1, 1, 3, 3 },
		battery     = { 2, 6, 3, 3 },
		-- Dos gauges de red: bajada primero (▾), subida (▴)
		network_down = { 2, 1, 3, 3 },
		network_up   = { 1, 2, 3, 3 },
		-- Mismos márgenes verticales que CPU (círculo gauge.monitor.circle)
		bluetooth    = { 6, 2, 3, 3 },
		-- Solo icono (sin dash): márgenes más ajustados
		brightness   = { 4, 4, 3, 3 },
		network      = { 4, 4, 7, 7 },
		updates     = { 6, 6, 6, 6 },
		taglist     = { 4, 4, 5, 4 },
		tasklist    = { 10, 0, 0, 0 }, -- centering tasklist widget
	}

	-- Various widgets style tuning
	------------------------------------------------------------

	-- Tabla periódica de atajos: keycap arriba, descripción debajo (layout vertical por entrada)
	theme.float.hotkeys = {
		geometry      = { width = 1000 },
		border_width  = 0,
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		border_margin = { 16, 16, 14, 14 },
		tspace        = 6,
		font          = "Sans 9",
		keyfont       = "Monospace bold 10",
		keycap_font   = "Monospace bold 10",
		titlefont     = "Sans bold 12",
		keycap_size   = 22,
		keycap_chars  = 4,
		keycap_join   = "+",
		heights       = { key = 14, title = 22 },
		description_max_len = 38,
		mod_short     = { Mod4 = "⊞", Control = "Ctrl", Shift = "⇧", Mod1 = "Alt" },
		key_short     = { Return = "↵", space = "Spc", Tab = "⇥", BackSpace = "⌫" },
		color         = {
			border    = pal.border,
			wibox     = pal.surface,
			text      = pal.hk_text,
			main      = theme.color.main,
			gray      = pal.hk_gray,
			keycap_bg = pal.keycap_bg,
			keycap_fg = pal.keycap_fg,
		},
	}

	-- Urgency hint: color llamativo en taglist (orange) y tasklist (Jiyu) para ventanas urgentes
	-- El color base theme.color.urgent (#016B84) era demasiado discreto; se usa naranja intenso.
	theme.gauge.tag.orange = redutil.table.merge(theme.gauge.tag.orange or {}, {
		color = { urgent = "#E07800", main = theme.color.main, gray = pal.tag_gray, icon = pal.tag_icon },
	})
	theme.gauge.task.Jiyu = redutil.table.merge(theme.gauge.task.Jiyu or {}, {
		color = { urgent = "#E07800", main = theme.color.main, gray = pal.tag_gray, icon = pal.tag_icon },
	})

	-- System updates indicator
	theme.widget.updates.icon = theme.path .. "/widget/updates.svg"

	-- Audio (panel): audio.svg + franja roja desde abajo según volumen; 0%% o silenciado → mute.svg en gris
	theme.gauge.audio.blue.dash.plain = true
	theme.gauge.audio.blue.dash.bar.num = 8
	theme.gauge.audio.blue.dash.bar.width = 3
	theme.gauge.audio.blue.dmargin = { 5, 0, 9, 9 }
	theme.gauge.audio.blue.width = 86
	theme.gauge.audio.blue.icon = theme.path .. "/widget/audio.svg"
	theme.gauge.audio.blue.icon_muted = theme.path .. "/widget/mute.svg"
	theme.gauge.audio.blue.icon_input_meter = true
	theme.gauge.audio.blue.icon_mute_at_zero = true
	theme.gauge.audio.blue.icon_fill_from_bottom = true
	theme.gauge.audio.blue.color = { on = theme.color.main, off = pal.off }

	-- Brillo: mismo criterio que volumen (brightness.svg + franja roja desde abajo; 0%% → brightness-off.svg)
	theme.gauge.backlight.red.dash.plain = true
	theme.gauge.backlight.red.dash.bar.num = 8
	theme.gauge.backlight.red.dash.bar.width = 3
	theme.gauge.backlight.red.dmargin = { 5, 0, 9, 9 }
	theme.gauge.backlight.red.width = 86
	theme.gauge.backlight.red.icon_lerp = false
	theme.gauge.backlight.red.icon_input_meter = true
	theme.gauge.backlight.red.icon = theme.path .. "/widget/brightness.svg"
	theme.gauge.backlight.red.icon_muted = theme.path .. "/widget/brightness-off.svg"
	theme.gauge.backlight.red.icon_mute_at_zero = true
	theme.gauge.backlight.red.icon_fill_from_bottom = true
	theme.gauge.backlight.red.color = { on = theme.color.main, off = pal.off }
	theme.gauge.backlight.red.dash.color = { main = theme.color.main, gray = pal.dash_gray }

	-- Dash (batería u otros)
	theme.gauge.monitor.dash.width = 11

	-- Separadores sutiles y estéticos (gradiente suave)
	theme.gauge.separator = {
		marginv = { 1, 1, 3, 3 },
		marginh = { 5, 5, 1, 1 },
		color   = { shadow1 = pal.sep_shadow1, shadow2 = pal.sep_shadow2 },
	}

	-- CPU / RAM / red: anillos circulares en el panel (ligeramente más compactos para caber con 2× red)
	theme.gauge.monitor.circle = {
		width      = 26,
		radius     = 9,
		line_width = 3,
		iradius    = 4,
		step       = 0.05,
		color      = { main = theme.color.main, gray = pal.circle_gray, icon = pal.circle_icon },
	}

	-- Tasklist
	theme.widget.tasklist.char_digit = 5
	theme.widget.tasklist.task = theme.gauge.task.Jiyu
	theme.widget.tasklist.tasktip.max_width = 1200

	-- Minitray (cuadraditos del system tray)
	if pal.dots_gray then
		theme.gauge.graph.dots = redutil.table.merge(theme.gauge.graph.dots or {}, {
			color = { main = theme.color.main, gray = pal.dots_gray },
		})
	end

	-- KB layout indicator
	theme.widget.keyboard.icon = theme.path .. "/widget/keyboard.svg"
	if pal.widget_icon then
		theme.widget.keyboard = redutil.table.merge(theme.widget.keyboard or {}, {
			menu           = { color = { right_icon = pal.widget_icon, left_icon = pal.widget_icon } },
			layout_color   = { pal.widget_icon, theme.color.main },
			fallback_color = theme.color.main,
		})
	end

	-- Mail
	theme.widget.mail.icon = theme.path .. "/widget/mail.svg"
	if pal.widget_icon then
		theme.widget.mail.color = redutil.table.merge(theme.widget.mail.color or {}, {
			main = theme.color.main, icon = pal.widget_icon,
		})
	end

	-- Textclock (hora del panel)
	theme.widget.textclock = redutil.table.merge(theme.widget.textclock or {}, {
		color = { text = theme.color.text },
	})

	-- Battery
	theme.widget.battery.notify = { icon = theme.path .. "/widget/battery.svg", color = theme.color.main }
	theme.widget.battery.levels = { 0.05, 0.1, 0.15, 0.2, 0.25, 0.30 }

	-- Individual styles
	------------------------------------------------------------
	-- Micrófono: mismo criterio que volumen — rojo desde abajo; 0%% o mute por software → microphone-mute.svg
	theme.individual.microphone_audio = {
		width                 = 26,
		icon                  = theme.path .. "/widget/microphone.svg",
		icon_muted            = theme.path .. "/widget/microphone-mute.svg",
		icon_input_meter      = true,
		icon_mute_at_zero     = true,
		icon_fill_from_bottom = true,
		color                 = { on = theme.color.main, off = pal.mic_off },
	}

	-- Floating widgets
	-------------------------------------------------------------------------------------------------------------------

	-- Titlebar helper
	theme.float.bartip.names = { "Mini", "Compact", "Full" }

	-- client menu tag line (icon.tag: base-colorless → icons/menu/applications.svg)
	theme.widget.tasklist.winmenu.enable_tagline = false

	theme.float.clientmenu.enable_tagline = false
	theme.float.clientmenu = redutil.table.merge(theme.float.clientmenu or {}, {
		color = {
			main      = theme.color.main,
			icon      = theme.color.icon,
			gray      = theme.color.gray,
			highlight = theme.color.highlight,
		},
	})

	-- Set hotkey helper size according current fonts and keys scheme
	--------------------------------------------------------------------------------
	theme.float.hotkeys.geometry           = { width = 1100 }
	theme.float.hotkeys.border_margin      = { 4, 4, 4, 4 }
	theme.float.hotkeys.tspace             = 2
	theme.float.hotkeys.border_width       = 1
	theme.float.hotkeys.heights            = { key = 20, title = 18 }
	theme.float.hotkeys.delim              = " "
	theme.float.hotkeys.keycap_size        = 20
	theme.float.hotkeys.keycap_chars       = 2
	theme.float.hotkeys.keycap_font        = "Monospace Bold 16"
	theme.float.hotkeys.keycap_join        = ""
	-- Tabla periódica (popup Shift+Super+F1): cada ficha de color = cuadrado N×N px.
	theme.float.hotkeys.periodic_tile_size   = 120
	theme.float.hotkeys.periodic_keycap_size = 18
	theme.float.hotkeys.periodic_desc_font   = "Sans 8"
	theme.float.hotkeys.description_max_len = 38
	theme.float.hotkeys.font               = "Sans 9"
	theme.float.hotkeys.keyfont            = "Sans 9"
	theme.float.hotkeys.titlefont          = "Sans bold 10"
	theme.float.hotkeys.mod_short = {
		Control = "C",
		Shift = "S",
		Mod1 = "A",
		Mod4 = "M",
	}
	theme.float.hotkeys.key_short = {
		Return = "↵",
		space = "␣",
		Prior = "Pg↑",
		Next = "Pg↓",
		Insert = "Ins",
		Delete = "Del",
		Escape = "Esc",
		Tab = "⇥",
		Left = "←",
		Right = "→",
		Up = "↑",
		Down = "↓",
	}
	theme.float.hotkeys.color         = redutil.table.merge(theme.float.hotkeys.color or {}, {
		keycap_bg = pal.keycap_bg2,
		keycap_fg = pal.keycap_fg2,
	})
	theme.float.appswitcher.keytip = { geometry = { width = 400 }, exit = true }
	theme.float.keychain.keytip    = { geometry = { width = 1020 }, column = 2 }
	theme.float.top.keytip         = { geometry = { width = 400 } }

	-- CPU y RAM: mismos grises (antes azul / marrón por panel)
	local top_process_gray = {
		action_button = {
			color = pal.ab,
		},
		color = {
			border    = pal.border,
			text      = theme.color.text,
			highlight = pal.highlight,
			main      = theme.color.main,
			bg        = pal.float_bg,
			bg_second = pal.float_bg2,
			wibox     = pal.surface,
		},
	}
	theme.float.top_cpu = {
		geometry      = { width = 500, height = 360 },
		border_width  = 0,
		border_margin = { 16, 16, 14, 14 },
		title_height  = 46,
		labels_width  = { num = 34, cpu = 82, mem = 120, action_kill = 58 },
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		action_button = top_process_gray.action_button,
		keytip        = theme.float.top.keytip,
		color         = top_process_gray.color,
	}
	theme.float.top_mem = {
		geometry      = { width = 500, height = 360 },
		border_width  = 0,
		border_margin = { 16, 16, 14, 14 },
		title_height  = 46,
		labels_width  = { num = 34, cpu = 70, mem = 128, action_kill = 58 },
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		action_button = top_process_gray.action_button,
		keytip        = theme.float.top.keytip,
		color         = top_process_gray.color,
	}
	theme.float.apprunner.keytip   = { geometry = { width = 400 } }
	-- Cierre automático de flotantes (calendario, top CPU/RAM, red) tras N s con el ratón fuera
	theme.float.autohide_timeout = 3
	theme.widget.updates.keytip    = { geometry = { width = 400 } }
	theme.menu.keytip              = { geometry = { width = 400 } }

	-- Notificación flotante (volumen, brillo, batería): esquinas redondeadas + fondo semitransparente
	theme.float.notify = redutil.table.merge(theme.float.notify or {}, {
		border_width = 0,
		shape        = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 10) end,
		color        = { border = pal.border, wibox = pal.surface, icon = pal.notify_icon },
	})

	-- Calendario flotante: castellano y más alto (mes/año abajo no cortados)
	theme.float.calendar.use_spanish = true
	theme.float.calendar.geometry = { width = 410, height = 540 }
	theme.float.calendar.margin = { 22, 22, 22, 34 }
	theme.float.calendar.controls_bottom_padding = 14
	theme.float.calendar.month_width_probe = " septiembre "
	theme.float.calendar.weekday_name_replacements = {
		Mon = "lu", Tue = "ma", Wed = "mi", Thu = "ju", Fri = "vi", Sat = "sá", Sun = "do",
	}
	theme.float.calendar.border_width = 0
	theme.float.calendar.shape = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end
	theme.float.calendar.color = redutil.table.merge(theme.float.calendar.color or {}, {
		wibox     = pal.surface,
		border    = pal.border,
		highlight = theme.color.main,
		gray      = pal.cal_gray,
		text      = theme.color.text,
	})
	theme.float.calendar.days = redutil.table.merge(theme.float.calendar.days or {}, {
		weekday  = { fg = pal.cal_wd_fg, bg = "transparent" },
		weekend  = { fg = pal.cal_we_fg, bg = pal.cal_we_bg },
		today    = { fg = "#ffffff", bg = theme.color.main },
		day      = { fg = pal.cal_day_fg, bg = "transparent" },
		default  = { fg = pal.cal_def_fg, bg = "transparent" },
	})

	-- Panel de red (NetworkManager / nmcli); campo contraseña alineado con gauge.monitor (CPU/RAM)
	theme.float.netctl = {
		geometry      = { width = 460, height = 560 },
		border_width  = 0,
		row_spacing   = 4,
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		border_margin = { 14, 14, 12, 12 },
		wifi_max_rows = 32,
		fonts         = {
			title           = "Sans bold 12",
			section         = "Sans 8",
			row             = "Sans 11",
			hint            = "Sans 9",
			password        = theme.fonts.main,
			password_toggle = theme.fonts.hint,
		},
		-- Franja vertical = grosor del arco CPU/RAM; alto = diámetro del gauge circular
		password_strip = {
			width  = theme.gauge.monitor.circle.line_width,
			height = theme.gauge.monitor.circle.width,
		},
		password_toggle = {
			color = {
				shadow3 = pal.pwd_shadow3,
				shadow4 = pal.pwd_shadow4,
				button  = pal.pwd_button,
				text    = theme.color.text,
				pressed = pal.pwd_pressed,
			},
		},
		password_field = {
			color = {
				bg      = pal.pwd_bg,
				shadow1 = pal.pwd_shadow1,
				shadow2 = pal.pwd_shadow2,
			},
		},
		color         = {
			border    = pal.border,
			wibox     = pal.surface,
			text      = theme.color.text,
			main      = theme.color.main,
			highlight = pal.highlight,
			gray      = pal.float_gray,
			bg        = pal.float_bg,
			bg_alt    = pal.float_bg2,
			muted     = pal.muted,
			sep       = pal.sep,
		},
	}

	-- Barra de brillo: posición fija (set_position abajo); autocierre 3 s al sacar el ratón; clic otra vez en el icono cierra.
	theme.float.brightctl = {
		autohide_timeout = 3,
		geometry      = { width = 320, height = 152 },
		max_width     = 400,
		max_height    = 260,
		min_width     = 280,
		min_height    = 130,
		border_margin = { 14, 14, 10, 10 },
		border_width  = 0,
		row_spacing   = 8,
		button_size   = 30,
		button_step   = 5,
		icon          = theme.path .. "/widget/brightness.svg",
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		shape_clip    = false,
		slider        = {
			track_width         = 190,
			bar_height          = 6,
			handle_width        = 18,
			forced_height       = 30,
			bar_margins         = { top = 6, bottom = 6 },
			handle_border_width = 0,
			handle_color        = theme.color.main,
			handle_border_color = pal.slider_track,
			bar_color           = pal.slider_track,
			bar_active_color    = theme.color.main,
		},
		fonts         = {
			hint  = theme.fonts.hint,
			pct   = "Sans bold 18",
			title = "Sans 9",
		},
		color         = {
			border    = pal.border,
			wibox     = pal.surface,
			text      = theme.color.text,
			main      = theme.color.main,
			highlight = pal.highlight,
			gray      = pal.float_gray,
			bg        = pal.float_bg,
			bg_alt    = pal.float_bg2,
			muted     = pal.muted,
			sep       = pal.sep,
		},
	}
	-- Misma esquina que pulsectl (evita under_mouse / shape_clip rotos).
	theme.float.brightctl.set_position = function(wibox)
		local s = wibox and wibox.screen or awful.screen.focused() or screen[1]
		if not s then
			return
		end
		local wa = s.workarea
		wibox:geometry({ x = wa.x + wa.width, y = wa.y + wa.height })
	end

	-- Selector de salida/entrada (pactl). Vista micrófono: solo capturas, panel más bajo/estrecho; crece con el contenido.
	theme.float.pulsectl = {
		-- Estilo "Task Manager": arranca compacto y crece con las filas.
		geometry      = { width = 520, height = 200 },
		max_width     = 860,
		max_height    = 1700,
		min_width     = 520,
		min_height    = 160,
		-- Con scope "sources" (icono micrófono): panel más alto y ancho para que
		-- quepan nombres + slider sin verse “micro”.
		min_width_sources   = 480,
		min_height_sources  = 140,
		border_margin = { 16, 16, 14, 14 },
		border_width  = 0,
		row_spacing   = 4,
		input_list_includes_monitors = false,
		-- “Task Manager”: mientras está abierto, refresca para que crezca al
		-- conectar/desconectar dispositivos.
		auto_refresh_interval = 3.0,
		-- PipeWire/Pulse a veces tarda en reflejar nuevos sinks/sources.
		-- Alargar el autocierre para que el auto-refresh alcance a capturarlos.
		autohide_timeout = 4,
		-- Alto automático: mide el layout real (fit) + corrección solo si hace falta.
		dynamic_height = true,
		-- Opcional: fijar mínimos a mano (dynamic_base_height / dynamic_row_height).
		-- Mostrar contadores y scope para depurar.
		debug = false,
		view_tabs     = true,
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		shape_clip    = false,
		icon          = theme.path .. "/widget/audio.svg",
		vol_slider    = {
			track_width         = 620,
			bar_height          = 7,
			handle_width        = 18,
			forced_height       = 30,
			bar_margins         = { top = 5, bottom = 5 },
			handle_margins      = { top = 0, bottom = 0 },
			handle_border_width = 0,
			handle_color        = theme.color.main,
			handle_border_color = pal.slider_track,
			bar_color           = pal.slider_track,
			bar_active_color    = theme.color.main,
		},
		switch        = { width = 54, height = 26, radius = 13 },
		fonts         = {
			title   = "Sans bold 12",
			section = "Sans 8",
			row     = "Sans 11",
			hint    = "Sans 9",
		},
		color         = {
			border    = pal.border,
			wibox     = pal.surface,
			text      = theme.color.text,
			main      = theme.color.main,
			highlight = pal.highlight,
			gray      = pal.float_gray,
			bg        = pal.float_bg,
			bg_alt    = pal.float_bg2,
			muted     = pal.muted,
			sep       = pal.sep,
		},
	}
	-- Esquina inferior derecha usando wibox.screen (asignado en show antes de esto). No usar mouse.screen.
	theme.float.pulsectl.set_position = function(wibox)
		local s = wibox and wibox.screen or awful.screen.focused() or screen[1]
		if not s then
			return
		end
		local wa = s.workarea
		wibox:geometry({ x = wa.x + wa.width, y = wa.y + wa.height })
	end

	-- Panel solo micrófono (instancia separada de pulsectl): tamaño propio, sin arrastrar el alto de salida.
	theme.float.pulsectl_sources = redutil.table.merge(theme.float.pulsectl, {
		geometry           = { width = 480, height = 280 },
		min_width          = 480,
		min_height         = 200,
		min_height_sources = 200,
		shape_clip         = false,
		icon               = theme.path .. "/widget/microphone.svg",
	})

	-- Bluetooth: popup con el mismo estilo que brillo/audio
	theme.widget.bluetooth = redutil.table.merge(theme.widget.bluetooth or {}, {
		panel_icon    = theme.path .. "/widget/bluetooth.svg",
		geometry      = { width = 360, height = 480 },
		border_width  = 0,
		border_margin = { 14, 14, 12, 12 },
		row_spacing   = 4,
		shape         = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end,
		fonts         = {
			title   = "Sans bold 12",
			section = "Sans 8",
			row     = "Sans 11",
			hint    = "Sans 9",
		},
		color         = {
			main      = theme.color.main,
			icon      = pal.bt_icon,
			gray      = pal.bt_gray,
			wibox     = pal.surface,
			border    = pal.border,
			text      = theme.color.text,
			highlight = pal.highlight,
			bg        = pal.float_bg,
			bg_second = pal.float_bg2,
			muted     = pal.muted,
			sep       = pal.sep,
		},
	})

	-- ── Estilo unificado para todos los popups flotantes ───────────────────────────────────────────
	local _r = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 12) end
	local _popup_color = {
		border    = pal.border,
		wibox     = pal.surface_blur,
		text      = theme.color.text,
		main      = theme.color.main,
		highlight = pal.highlight,
		bg        = pal.popup_bg,
		bg_second = pal.popup_bg2,
		icon      = pal.popup_icon,
		gray      = pal.popup_gray,
	}

	-- Aplicar colores unificados a todos los floats
	for _, float in pairs(theme.float) do
		if type(float) == "table" and float.color then
			float.color = redutil.table.merge(float.color, _popup_color)
		end
	end

	-- Segundo pase forzado sobre hotkeys (p. ej. fondo opaco en tema claro)
	if pal.hk_forced then
		theme.float.hotkeys.color = redutil.table.merge(theme.float.hotkeys.color or {}, _popup_color, pal.hk_forced)
	end

	-- Popup de procesos (CPU/RAM)
	theme.float.top = redutil.table.merge(theme.float.top or {}, {
		color = {
			border    = pal.border,
			text      = theme.color.text,
			highlight = pal.highlight,
			main      = theme.color.main,
			bg        = pal.float_bg,
			bg_second = pal.float_bg2,
			wibox     = pal.surface,
		},
		action_button = {
			color = pal.ab_top,
		},
	})

	-- Minitray popup
	theme.widget.minitray = redutil.table.merge(theme.widget.minitray or {}, {
		color = {
			wibox  = pal.minitray_wibox,
			border = pal.border,
		},
	})

	-- Buscador de aplicaciones (Alt+F2)
	theme.float.apprunner = redutil.table.merge(theme.float.apprunner or {}, {
		border_width = 0,
		shape        = _r,
		color        = redutil.table.merge(_popup_color, { bg_second = pal.apprunner_bg2, icon = pal.popup_icon }),
	})

	-- Switcher de ventanas abiertas
	theme.float.appswitcher = redutil.table.merge(theme.float.appswitcher or {}, {
		border_width   = 0,
		shape          = _r,
		wibox_height   = 300, -- mayor altura para mejor resolución
		icon_size      = 64,  -- iconos más grandes para ventanas minimizadas
		preview_format = 16/10,
		update_timeout = 0.5, -- actualizaciones más frecuentes
		color          = redutil.table.merge(_popup_color, { preview_bg = theme.color.main .. "60" }),
	})

	-- Prompt flotante de texto
	theme.float.prompt = {
		border_width = 0,
		shape        = _r,
		color        = { border = pal.border, wibox = pal.surface },
	}

	-- Lanzador rápido de apps (dock)
	theme.float.qlaunch = redutil.table.merge(theme.float.qlaunch or {}, {
		border_width = 0,
		shape        = _r,
		color        = redutil.table.merge(_popup_color, { urgent = "#2e7d32" }),
	})

	-- Window thumbnails bar (winthumbs)
	theme.float.winthumbs = {
		bg             = pal.win_bg,
		border         = pal.border,
		label_fg       = theme.color.text,
		label_fg_focus = theme.color.text,
		thumb_bg       = pal.thumb_bg,
		thumb_bg_focus = pal.thumb_bg_focus,
	}

	-- Tooltips del panel
	theme.float.tooltip = {
		border_width = 0,
		shape        = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 6) end,
		font         = "Sans 10",
		color        = { border = pal.border, wibox = pal.surface_soft, text = theme.color.text },
	}

	-- Menú principal (sobrescribir defaults de redflat/menu.lua)
	theme.menu = redutil.table.merge(theme.menu or {}, {
		color = {
			border    = pal.border,
			text      = theme.color.text,
			highlight = theme.color.highlight,
			main      = theme.color.main,
			wibox     = pal.surface,
			gray      = theme.color.gray,
			icon      = pal.menu_icon,
			bg        = theme.color.bg,
			bg_second = theme.color.bg_second,
		},
	})

	-- Titlebar (sobrescribir defaults de redflat/titlebar.lua)
	theme.titlebar = theme.titlebar or {}
	theme.titlebar.base = redutil.table.merge(theme.titlebar.base or {}, {
		color = {
			main      = theme.color.main,
			wibox     = pal.tb_wibox,
			gray      = theme.color.gray,
			text      = theme.color.text,
			icon      = pal.menu_icon,
			urgent    = theme.color.urgent,
			highlight = theme.color.highlight,
		},
	})
	theme.titlebar.mark = redutil.table.merge(theme.titlebar.mark or {}, {
		color = theme.titlebar.base.color,
	})

	-- Tasklist tooltip (sobrescribir defaults de redflat/widget/tasklist.lua)
	theme.widget.tasklist.tasktip = redutil.table.merge(theme.widget.tasklist.tasktip or {}, {
		color = {
			border    = pal.border,
			text      = theme.color.text,
			main      = theme.color.main,
			highlight = theme.color.highlight,
			wibox     = pal.surface,
			gray      = pal.tasktip_gray,
			urgent    = theme.color.urgent,
		},
	})

	-- Updates widget (sobrescribir defaults de redflat/widget/updates.lua)
	theme.widget.updates = redutil.table.merge(theme.widget.updates or {}, {
		color = {
			main   = theme.color.main,
			icon   = theme.color.icon,
			wibox  = pal.surface,
			border = pal.border,
			gray   = theme.color.gray,
			urgent = "#2e7d32",
		},
	})

	-- Logout screen (sobrescribir defaults de redflat/service/logout.lua)
	theme.service = theme.service or {}
	theme.service.logout = redutil.table.merge(theme.service.logout or {}, {
		color = {
			wibox = pal.surface,
			text  = theme.color.text,
			icon  = pal.logout_icon,
			gray  = pal.logout_gray,
			main  = theme.color.main,
		},
	})

	-- Window navigator overlay (sobrescribir defaults de redflat/service/navigator.lua)
	theme.service.navigator = redutil.table.merge(theme.service.navigator or {}, {
		color = {
			border = pal.border,
			wibox  = "#00000000",
			bg1    = pal.border .. "40",
			bg2    = pal.border .. "20",
			fbg1   = theme.color.main .. "40",
			fbg2   = theme.color.main .. "20",
			mark   = pal.nav_mark,
			text   = theme.color.text,
			hbg1   = "#2e7d3240",
			hbg2   = "#2e7d3220",
		},
	})

	-- Notificaciones naughty (campos beautiful.notification_* leídos directamente por naughty/core)
	theme.notification_shape        = function(cr, w, h) require("gears").shape.rounded_rect(cr, w, h, 8) end
	theme.notification_border_width = 0
	theme.notification_bg           = pal.surface
	theme.notification_fg           = theme.color.text
	theme.notification_margin       = 8
	theme.notification_border_color = pal.border
	theme.notification_font         = theme.fonts and theme.fonts.tiny or "Sans 10"
	theme.notification_icon_size    = 24
	-- redflat naughty.base (usado por env-config para presets normal/low/critical;
	-- conserva base/normal/low/critical creados en init — no reasignar theme.naughty)
	theme.naughty = theme.naughty or {}
	theme.naughty.base = redutil.table.merge(theme.naughty.base or {}, {
		border_width = 0,
		bg           = pal.surface,
		fg           = theme.color.text,
		margin       = 8,
		font         = theme.fonts and theme.fonts.tiny or "Sans 10",
		icon_size    = 24,
	})

	-- Reproductor flotante MPRIS: más arriba desde la esquina inferior derecha (px hacia arriba).
	theme.float.player = redutil.table.merge(theme.float.player or {}, {
		bottom_anchor_lift = 160,
		border_width       = 0,
		shape              = _r,
		color              = redutil.table.merge(_popup_color, {}),
	})
	theme.float.player.set_position = function(wibox)
		local scr = awful.screen.focused()
		if not scr then
			return
		end
		local wa = scr.workarea
		local lift = theme.float.player.bottom_anchor_lift or 120
		wibox:geometry({ x = wa.x + wa.width, y = wa.y + wa.height - lift })
	end

	-- Titlebar: todos los SVG en themes/Jiyu/titlebar/ (botones y modo compact/full/mini)
	-- Botones minimizar/maximizar/cerrar: gris siempre; main al pasar el ratón (redflat usa color.urgent en hover).
	-------------------------------------------------------------------------------------------------------------------
	local _tb = theme.path .. "/titlebar/"
	local _titlebar_icons = {
		focus     = _tb .. "focus.svg",
		floating  = _tb .. "floating.svg",
		ontop     = _tb .. "ontop.svg",
		below     = _tb .. "below.svg",
		sticky    = _tb .. "pin.svg",
		maximized = _tb .. "maximized.svg",
		minimized = _tb .. "minimize.svg",
		close     = _tb .. "close.svg",
		menu      = _tb .. "menu.svg",
		unknown   = theme.icon.unknown,
	}
	local _titlebar_color = redutil.table.merge(redutil.table.merge({}, theme.color), {
		icon   = theme.color.gray,
		urgent = theme.color.main,
	})
	theme.titlebar.icon = redutil.table.merge(theme.titlebar.icon or {}, {
		list = _titlebar_icons,
		gray_until_hover = true,
		color = _titlebar_color,
	})
	theme.titlebar.icon_compact = redutil.table.merge(theme.titlebar.icon_compact or {}, {
		list = _titlebar_icons,
		gray_until_hover = true,
		color = _titlebar_color,
	})
end

return { apply = apply }
