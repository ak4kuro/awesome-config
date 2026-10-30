-----------------------------------------------------------------------------------------------------------------------
--        Tabla periódica de atajos: popup de cheatsheet con rejilla por grupos y vista de detalle ejecutable         --
--        Se abre con Mod4+Shift+F1. Compatible con Awesome 4.3 (margins numéricos, nada de tablas en margins).      --
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local wibox = require("wibox")
local L = require("Jiyu.locale").t

local M = {}

-- Estado del wibox persistente del popup
local popup = {
	wibox = nil,
	grid = nil,
	keygrabber = nil,
	area_constraint = nil,
	body_layout = nil,
	grab_timer = nil,
}

local function short_mod(m)
	local fh = beautiful.float and beautiful.float.hotkeys
	if fh and type(fh.mod_short) == "table" and fh.mod_short[m] then
		return fh.mod_short[m]
	end
	if m == "Mod4" then
		return "M"
	elseif m == "Control" then
		return "C"
	elseif m == "Mod1" then
		return "A"
	elseif m == "Shift" then
		return "S"
	end
	return tostring(m)
end

local function short_key(k)
	local fh = beautiful.float and beautiful.float.hotkeys
	if fh and type(fh.key_short) == "table" and fh.key_short[k] then
		return fh.key_short[k]
	end
	return tostring(k)
end

-- Extrae {group, combo, combo_long, desc, run} de cada entrada de un pack awful-style.
local function collect_cards(pack)
	local cards = {}
	for _, entry in ipairs(pack or {}) do
		-- La metadata es la última tabla con .description (posiciones 4-6; con huecos
		-- de callbacks press/release el operador # puede dar un índice menor y perderla).
		local meta, run = nil, nil
		for i = 6, 3, -1 do
			local v = entry[i]
			if type(v) == "table" and v.description then
				meta = v
				break
			end
		end
		for i = 3, 5 do
			local v = entry[i]
			if type(v) == "function" then
				run = v
				break
			end
		end
		if meta then
			local mods = entry[1] or {}
			local key = tostring(entry[2] or "")
			local combo, combo_long = {}, {}
			for _, m in ipairs(mods) do
				table.insert(combo, short_mod(m))
				table.insert(combo_long, tostring(m))
			end
			table.insert(combo, short_key(key))
			table.insert(combo_long, key)
			table.insert(cards, {
				group = tostring(meta.group or "Otros"),
				combo = table.concat(combo, "+"),
				combo_long = table.concat(combo_long, "+"),
				desc = tostring(meta.description),
				run  = run,
			})
		end
	end
	return cards
end

-- Versión "solo lectura" de un pack: muestra la combinación pero sin acción
-- (para teclas modales de layout, que solo tienen efecto dentro de su modo).
function M.strip_run(pack)
	local out = {}
	for _, e in ipairs(pack or {}) do
		local meta = nil
		for i = 6, 3, -1 do
			if type(e[i]) == "table" and e[i].description then meta = e[i]; break end
		end
		if meta then
			table.insert(out, { e[1], e[2], nil, meta })
		end
	end
	return out
end

local function group_color(group)
	local palette = {
		[L("Help")] = "#9C27B0",
		[L("Window control")] = "#7B1FA2",
		[L("Applications")] = "#E91E63",
		[L("Client focus")] = "#FF9800",
		[L("Widgets")] = "#8BC34A",
		[L("Application switcher")] = "#03A9F4",
		[L("Tag navigation")] = "#673AB7",
		[L("Launchers")] = "#009688",
		[L("Volume control")] = "#607D8B",
		[L("Brightness control")] = "#FFC107",
		[L("Audio player")] = "#00BCD4",
		[L("Layouts")] = "#3F51B5",
		["Keychain (Mod+c)"] = "#795548",
		[L("Client keys")] = "#CDDC39",
		[L("Tag Control")] = "#FF5722",
		[L("Screen")] = "#26C6DA",
		[L("Screenshots")] = "#EC407A",
		[L("Layout")] = "#3F51B5",
		[L("Resize")] = "#546E7A",
		[L("Movement")] = "#7C4DFF",
		[L("Mouse")] = "#8D6E63",
	}
	return palette[group] or "#616161"
end

-- Aclara/oscurece un color #RRGGBB en `amt` (-255..255) para el hover del ratón.
local function brighten(hex, amt)
	local r, g, b = tostring(hex):match("^#(%x%x)(%x%x)(%x%x)")
	if not r then return hex end
	local function up(h) return math.max(0, math.min(255, tonumber(h, 16) + amt)) end
	return string.format("#%02X%02X%02X", up(r), up(g), up(b))
end

-- Grupos en orden de primera aparición + nº de atajos de cada uno.
local function group_list(cards)
	local groups, seen, counts = {}, {}, {}
	for _, c in ipairs(cards or {}) do
		local g = c.group
		counts[g] = (counts[g] or 0) + 1
		if not seen[g] then
			seen[g] = true
			groups[#groups + 1] = g
		end
	end
	return groups, counts
end

-- Parte un nombre largo en dos líneas por el espacio más cercano al centro.
local function wrapped_name(name, tile)
	local s = tostring(name or "")
	local limit = math.max(10, math.floor((tile - 20) / 9))
	if #s <= limit then return s end
	local best_i, best_d = nil, math.huge
	for i = 1, #s do
		if s:sub(i, i) == " " then
			local d = math.abs(i - #s / 2)
			if d < best_d then best_i, best_d = i, d end
		end
	end
	if not best_i then return s end
	return s:sub(1, best_i - 1) .. "\n" .. s:sub(best_i + 1)
end

-- Ficha de grupo: nombre grande centrado + nº de atajos abajo; clic abre el detalle.
local function build_group_tile(group, count, tile, on_click)
	local base_color = group_color(group)
	local name_pt = math.max(12, math.min(18, math.floor(tile / 11)))
	local count_pt = math.max(9, math.floor(tile / 16))
	local name = wibox.widget({
		markup = string.format(
			'<span font="Lato Bold %d" color="#ffffff">%s</span>',
			name_pt,
			gears.string.xml_escape(wrapped_name(group, tile))
		),
		align = "center",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	local num = wibox.widget({
		markup = string.format(
			'<span font="Lato %d" color="#f0f0f0">%s</span>',
			count_pt,
			gears.string.xml_escape(string.format(L("%d shortcuts"), count))
		),
		align = "center",
		valign = "bottom",
		widget = wibox.widget.textbox,
	})
	local inner = wibox.widget({
		{ nil, name, num, layout = wibox.layout.align.vertical },
		margins = 8,
		widget = wibox.container.margin,
	})
	local bgw = wibox.widget({
		inner,
		forced_width = tile,
		forced_height = tile,
		bg = base_color,
		widget = wibox.container.background,
	})
	bgw:connect_signal("mouse::enter", function()
		bgw.bg = brighten(base_color, 40)
		if popup.wibox then popup.wibox.cursor = "hand2" end
	end)
	bgw:connect_signal("mouse::leave", function()
		bgw.bg = base_color
		if popup.wibox then popup.wibox.cursor = "left_ptr" end
	end)
	if on_click then
		bgw:buttons(awful.button({}, 1, on_click))
	end
	return bgw
end

local function popup_hide()
	if popup.grab_timer then
		popup.grab_timer:stop()
		popup.grab_timer = nil
	end
	if not popup.wibox then return end
	popup.wibox.visible = false
	if popup.keygrabber then awful.keygrabber.stop(popup.keygrabber) end
end

-- Ejecuta el atajo seleccionado (misma callback que la pulsación de teclas).
local function run_card(card)
	popup_hide()
	if not card.run then return end
	local okc, err = pcall(card.run, client.focus)
	if not okc then
		local naughty = require("naughty")
		naughty.notify({
			title = L("Hotkey"),
			text = tostring(err),
			timeout = 4,
		})
	end
end

-- Vuelve a la vista de rejilla (todas las fichas).
local function show_grid()
	popup.current_view = "grid"
	if not popup.body_layout then return end
	popup.body_layout:reset()
	popup.body_layout:add(popup.title_widget)
	popup.body_layout:add(popup.area_constraint)
end

-- Fila de detalle: combinación + descripción + ▶ si es ejecutable.
local function build_row(card)
	local base = group_color(card.group)
	local bg_normal = brighten(base, -36)
	local bg_hover  = brighten(base, 8)
	local combo = wibox.widget({
		markup = string.format(
			'<span font="Monospace Bold 10" color="#fffde7">%s</span>',
			gears.string.xml_escape(card.combo)
		),
		align = "left",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	combo.forced_width = 190
	local desc = wibox.widget({
		markup = string.format(
			'<span font="Lato 10" color="#f0f0f0">%s</span>',
			gears.string.xml_escape(card.desc)
		),
		align = "left",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	if desc.set_ellipsize then
		desc:set_ellipsize("end")
	end
	local play = wibox.widget({
		markup = card.run and '<span font="Lato 10" color="#ffffff">▶</span>' or "",
		align = "right",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	play.forced_width = 26
	local row = wibox.widget({
		{
			combo,
			desc,
			play,
			spacing = 12,
			layout = wibox.layout.align.horizontal,
		},
		left = 10,
		right = 10,
		top = 7,
		bottom = 7,
		widget = wibox.container.margin,
	})
	row = wibox.widget({
		row,
		bg = bg_normal,
		widget = wibox.container.background,
	})
	row:connect_signal("mouse::enter", function()
		row.bg = bg_hover
		if popup.wibox then popup.wibox.cursor = "hand2" end
	end)
	row:connect_signal("mouse::leave", function()
		row.bg = bg_normal
		if popup.wibox then popup.wibox.cursor = "left_ptr" end
	end)
	row:buttons(awful.button({}, 1, function() run_card(card) end))
	return row
end

-- Vista de detalle: cabecera del grupo + filas con todos sus atajos (árbol del seleccionado).
local function show_detail(group)
	if not popup.body_layout then return end
	popup.current_view = "detail"
	local base = group_color(group)
	local rows = {}
	for _, c in ipairs(popup.cards or {}) do
		if c.group == group then
			rows[#rows + 1] = c
		end
	end

	local header = wibox.widget({
		markup = string.format(
			'<span font="Lato Bold 12" color="#ffffff">◀ %s</span>   <span font="Lato 9" color="#ffffff">%s</span>',
			gears.string.xml_escape(group),
			string.format(L("%d shortcuts — click a row to run it"), #rows)
		),
		align = "left",
		valign = "center",
		widget = wibox.widget.textbox,
	})
	local header_bg = wibox.widget({
		{ header, left = 12, right = 12, top = 8, bottom = 8, widget = wibox.container.margin },
		bg = base,
		widget = wibox.container.background,
	})
	header_bg:connect_signal("mouse::enter", function()
		header_bg.bg = brighten(base, 32)
		if popup.wibox then popup.wibox.cursor = "hand2" end
	end)
	header_bg:connect_signal("mouse::leave", function()
		header_bg.bg = base
		if popup.wibox then popup.wibox.cursor = "left_ptr" end
	end)
	header_bg:buttons(awful.button({}, 1, show_grid))

	-- Dos columnas cuando el grupo es grande para no desbordar la pantalla.
	local cols = math.max(1, math.min(3, math.ceil(#rows / 14)))
	local list = wibox.layout.grid()
	list.spacing = 6
	list.forced_num_cols = cols
	list.homogeneous = true
	for _, c in ipairs(rows) do
		list:add(build_row(c))
	end

	popup.body_layout:reset()
	popup.body_layout:add(popup.title_widget)
	popup.body_layout:add(header_bg)
	popup.body_layout:add(list)
end

function M.show(pack)
	local scr = awful.screen.focused()
	if not scr then return end
	local wa = scr.workarea
	-- Marco del wibox + margen interno (mismo valor): el área útil real es wa - 4*frame_m.
	local frame_m = 10
	local title_spacing = 8
	local title_reserve = 40
	local wbox_w = wa.width - 2 * frame_m
	local wbox_h = wa.height - 2 * frame_m
	local content_w = math.max(280, wbox_w - 2 * frame_m)
	local content_h = math.max(200, wbox_h - 2 * frame_m)
	local avail_w = content_w
	local avail_h = math.max(160, content_h - title_reserve - title_spacing)

	local cards = collect_cards(pack)
	local groups, counts = group_list(cards)
	-- Una ficha grande por grupo: pocas, legibles; los atajos van en la vista de detalle.
	local n = #groups
	local spacing = 8
	local max_tile = 240
	local min_tile = 110
	local max_cols = math.min(8, math.max(3, math.floor((avail_w + spacing) / (min_tile + spacing))))

	local best_t, best_c = min_tile, math.min(max_cols, 6)
	local found = false
	if n > 0 then
		for t = max_tile, min_tile, -2 do
			for c = max_cols, 3, -1 do
				local rows = math.ceil(n / c)
				local gw = c * t + (c - 1) * spacing
				local gh = rows * t + (rows - 1) * spacing
				if gw <= avail_w and gh <= avail_h then
					best_t, best_c, found = t, c, true
					break
				end
			end
			if found then break end
		end
	end
	if not found and n > 0 then
		best_c = max_cols
		best_t = min_tile
	end

	if not popup.wibox then
		popup.grid = wibox.layout.grid()
		popup.grid.homogeneous = true

		popup.title_widget = wibox.widget({
			markup = "<b>Tabla periodica de atajos</b>  <span color='#ffd54f'>[Mod4+Shift+F1]</span>  (clic: grupo · clic der/Esc: volver-cerrar)",
			align = "center",
			widget = wibox.widget.textbox,
		})

		popup.area_constraint = wibox.container.constraint(popup.grid, "max", nil, nil)

		popup.body_layout = wibox.layout.fixed.vertical()
		popup.body_layout.spacing = title_spacing
		popup.body_layout:fill_space(true)
		popup.body_layout:add(popup.title_widget)
		popup.body_layout:add(popup.area_constraint)

		popup.wibox = wibox({
			ontop = true,
			visible = false,
			bg = "#121212EE",
			border_width = 2,
			border_color = "#3A3A3A",
			type = "splash",
		})
		popup.wibox:setup({
			popup.body_layout,
			margins = frame_m,
			widget = wibox.container.margin,
		})
		-- Clic derecho en cualquier zona: en detalle vuelve al grid, en grid cierra.
		popup.wibox:buttons(awful.button({}, 3, function()
			if popup.current_view == "detail" then
				show_grid()
			else
				popup_hide()
			end
		end))

		-- Esc/Retroceso: en vista detalle vuelve al grid; en grid cierra.
		-- Solo teclas (no Mod_L): al soltar Mod tras Mod+Shift+F1 el popup desaparecería al instante.
		popup.keygrabber = function(_, key, event)
			if event ~= "release" then return end
			if key == "Escape" then
				if popup.current_view == "detail" then
					show_grid()
				else
					popup_hide()
				end
			elseif key == "BackSpace" and popup.current_view == "detail" then
				show_grid()
			end
		end
	end

	popup.cards = cards
	popup.current_view = "grid"
	popup.grid.spacing = spacing
	popup.grid.forced_num_cols = best_c

	popup.grid:reset()
	for _, g in ipairs(groups) do
		popup.grid:add(build_group_tile(g, counts[g], best_t, function()
			show_detail(g)
		end))
	end
	-- Asegurar vista grid (por si la última sesión quedó en detalle)
	show_grid()

	popup.wibox.screen = scr
	popup.wibox:geometry({
		x = wa.x + frame_m,
		y = wa.y + frame_m,
		width = wbox_w,
		height = wbox_h,
	})
	popup.wibox.visible = true

	-- Retrasar el grabber para no capturar la suelta de teclas del atajo que abre el popup.
	if popup.grab_timer then
		popup.grab_timer:stop()
	end
	popup.grab_timer = gears.timer({
		timeout = 0.12,
		single_shot = true,
		callback = function()
			popup.grab_timer = nil
			if popup.wibox and popup.wibox.visible and popup.keygrabber then
				awful.keygrabber.run(popup.keygrabber)
			end
		end,
	})
	popup.grab_timer:start()
end

-- Genera ATAJOS.md desde el mismo pack que muestra la tabla (fuente única de verdad).
-- Uso: echo 'JIYU_DUMP_HOTKEYS()' | awesome-client
function M.dump_md(pack, path)
	path = path or (os.getenv("HOME") .. "/.config/awesome/ATAJOS.md")
	local cards = collect_cards(pack)
	local groups, counts = group_list(cards)
	local lines = {
		"# Atajos de Teclado (Awesome - Jiyu)",
		"",
		"Generado automáticamente desde la config: `echo 'JIYU_DUMP_HOTKEYS()' | awesome-client`",
		"",
		"**Convenciones**: `Mod4` = Super/Windows. La tabla periódica interactiva se abre con **Mod4 + Shift + F1**.",
		"Las entradas marcadas *(modo M+F2)* solo funcionan dentro del navegador de layouts.",
		"",
	}
	for _, g in ipairs(groups) do
		lines[#lines + 1] = "## " .. g .. " (" .. counts[g] .. ")"
		lines[#lines + 1] = ""
		lines[#lines + 1] = "| Atajo | Acción |"
		lines[#lines + 1] = "|---|---|"
		for _, c in ipairs(cards) do
			if c.group == g then
				local desc = tostring(c.desc):gsub("|", "\\|")
				lines[#lines + 1] = "| `" .. c.combo_long .. "` | " .. desc .. " |"
			end
		end
		lines[#lines + 1] = ""
	end
	local f = io.open(path, "w")
	if not f then return nil, "no se pudo escribir " .. tostring(path) end
	f:write(table.concat(lines, "\n"))
	f:close()
	return path
end

return M
