-----------------------------------------------------------------------------------------------------------------------
--  Mic / volumen: gris + rojo en franja superior; silenciado → icon_muted en gris.                                   --
--  Dibujo vía gears.color.recolor_image (misma idea que el tema) — evita máscaras Cairo frágiles con Pixbuf/SVG.       --
-----------------------------------------------------------------------------------------------------------------------
local math = math
local type = type
local base = require("wibox.widget.base")
local surface = require("gears.surface")
local color = require("gears.color")

-- [path .. "\0" .. hex] → superficie ARGB recoloreada (pequeña caché)
local colored_cache = {}

local function intrinsic_size(path)
	if type(path) ~= "string" then
		return 48, 48
	end
	local ok, img = pcall(surface.load, path)
	if ok and img and img.width > 0 and img.height > 0 then
		return img.width, img.height
	end
	return 48, 48
end

local function get_colored_surface(path, col_hex)
	if type(path) ~= "string" or not col_hex then
		return nil
	end
	local key = path .. "\0" .. col_hex
	local hit = colored_cache[key]
	if hit then
		return hit
	end
	local ok, img = pcall(surface.load, path)
	if not ok or not img then
		return nil
	end
	local dup = surface.duplicate_surface(img)
	if not dup then
		return nil
	end
	local ok2, out = pcall(color.recolor_image, dup, col_hex)
	if not ok2 or not out then
		return nil
	end
	colored_cache[key] = out
	return out
end

local function paint_scaled(cr, surf, width, height)
	if not surf then
		return
	end
	local iw, ih = surf.width, surf.height
	if iw < 1 or ih < 1 then
		return
	end
	local a = math.min(width / iw, height / ih)
	local dw = math.max(1, math.floor(iw * a + 0.5))
	local dh = math.max(1, math.floor(ih * a + 0.5))
	local ox = (width - dw) / 2
	local oy = (height - dh) / 2
	cr:save()
	cr:translate(ox, oy)
	cr:scale(dw / iw, dh / ih)
	cr:set_source_surface(surf, 0, 0)
	cr:paint()
	cr:restore()
end

-- image_path, gray, red, [icon_muted_path], [opts]
-- opts.mute_at_zero: con icon_muted, a nivel 0 mostrar mute aunque no esté silenciado por software
-- opts.fill_from_bottom: la franja roja crece desde abajo (volumen); false = desde arriba (micrófono)
return function(image_path, gray_hex, red_hex, path_muted, opts)
	opts = opts or {}
	local w = base.make_widget()
	w._path = image_path
	w._path_muted = path_muted
	w._level = 0
	w._muted = false
	w._mute_at_zero = opts.mute_at_zero and true or false
	w._fill_from_bottom = opts.fill_from_bottom and true or false
	w._gray = gray_hex or "#909090"
	w._red = red_hex or "#b1222b"

	function w:set_level(l)
		l = tonumber(l) or 0
		w._level = math.max(0, math.min(1, l))
		w:emit_signal("widget::redraw_needed")
	end

	function w:set_muted(m)
		w._muted = m and true or false
		w:emit_signal("widget::redraw_needed")
	end

	function w:fit(_, width, height)
		local iw, ih = intrinsic_size(w._path)
		if type(w._path_muted) == "string" then
			local mw, mh = intrinsic_size(w._path_muted)
			iw, ih = math.max(iw, mw), math.max(ih, mh)
		end
		if width < 1 or height < 1 then
			return math.min(iw, 32), math.min(ih, 32)
		end
		local a = math.min(width / iw, height / ih)
		return math.max(1, math.floor(iw * a + 0.5)), math.max(1, math.floor(ih * a + 0.5))
	end

	local function show_mute_icon()
		return type(w._path_muted) == "string"
			and (w._muted or (w._mute_at_zero and w._level <= 0.001))
	end

	function w:draw(_, cr, width, height)
		if width < 1 or height < 1 then
			return
		end

		if show_mute_icon() then
			paint_scaled(cr, get_colored_surface(w._path_muted, w._gray), width, height)
			return
		end

		paint_scaled(cr, get_colored_surface(w._path, w._gray), width, height)

		if w._level > 0.001 then
			cr:save()
			local lv = w._level
			if w._fill_from_bottom then
				local h = height * lv
				cr:rectangle(0, height - h, width, h)
			else
				cr:rectangle(0, 0, width, height * lv)
			end
			cr:clip()
			paint_scaled(cr, get_colored_surface(w._path, w._red), width, height)
			cr:restore()
		end
	end

	return w
end
