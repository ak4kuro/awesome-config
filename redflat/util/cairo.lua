-- RedFlat util submodule


local cairo = { textcentre = {} }

-- Functions
-----------------------------------------------------------------------------------------------------------------------

-- Draw text aligned by center
------------------------------------------------------------
function cairo.textcentre.full(cr, coord, text)
	local ext = cr:text_extents(text)
	cr:move_to(coord[1] - (ext.width/2 + ext.x_bearing), coord[2] - (ext.height/2 + ext.y_bearing))
	cr:show_text(text)
end

-- Draw text aligned by center horizontal only
------------------------------------------------------------
function cairo.textcentre.horizontal(cr, coord, text)
	local ext = cr:text_extents(text)
	cr:move_to(coord[1] - (ext.width/2 + ext.x_bearing), coord[2])
	cr:show_text(text)
end

-- Set font
------------------------------------------------------------
function cairo.set_font(cr, font)
	if not font then
		return
	end
	-- Valores nil rompen select_font_face y el dibujo (panel/tasklist “vacío” sin error Lua).
	local size = font.size or 12
	local family = font.font or "sans"
	cr:set_font_size(size)
	cr:select_font_face(family, font.slant or 0, font.face or 0)
end


-- End
-----------------------------------------------------------------------------------------------------------------------
return cairo
