-----------------------------------------------------------------------------------------------------------------------
-- Parche: beautiful.get_font() solo admite string o Pango.FontDescription (userdata).
-- RedFlat y el tema usan tablas { font=, size=, face=, slant= } en algunos sitios; al llegar a textbox:set_font()
-- Awesome llama get_font(tabla) y load_font() falla en name:to_string().
-----------------------------------------------------------------------------------------------------------------------

local function normalize_font_arg(name, beautiful)
	if name == nil or name == "" then
		return name
	end
	if type(name) == "string" then
		return name
	end
	if type(name) == "table" then
		local f = name.font or name.family
		local s = name.size or 12
		if f then
			local parts = { tostring(f), tostring(s) }
			if name.face == 1 or name.bold then
				parts[#parts + 1] = "bold"
			end
			if name.slant == 1 or name.italic then
				parts[#parts + 1] = "italic"
			end
			return table.concat(parts, " ")
		end
		local t = beautiful.font
		return type(t) == "string" and t or "sans 8"
	end
	if type(name) == "number" then
		return tostring(name)
	end
	return name
end

local function apply()
	local beautiful = require("beautiful")
	if beautiful._redflat_font_safe_applied then
		return
	end
	beautiful._redflat_font_safe_applied = true

	local orig_get_font = beautiful.get_font
	function beautiful.get_font(name)
		return orig_get_font(normalize_font_arg(name, beautiful))
	end

	local orig_get_font_height = beautiful.get_font_height
	function beautiful.get_font_height(name)
		return orig_get_font_height(normalize_font_arg(name, beautiful))
	end

	local orig_merged = beautiful.get_merged_font
	if orig_merged then
		function beautiful.get_merged_font(name, merge)
			return orig_merged(normalize_font_arg(name, beautiful), merge)
		end
	end
end

return apply
