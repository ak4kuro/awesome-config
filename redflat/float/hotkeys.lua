-----------------------------------------------------------------------------------------------------------------------
--                                          RedFlat hotkeys helper widget                                            --
-----------------------------------------------------------------------------------------------------------------------
-- Widget with list of hotkeys
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local math = math
local unpack = unpack or table.unpack

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local timer = require("gears.timer")

local redflat = require("redflat")
local redutil = require("redflat.util")
local tr = require("redflat.util.lang").t


-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local hotkeys = { keypack = {}, lastkey = nil, cache = {}, boxes = {} }
local hasitem = awful.util.table.hasitem

-- key bindings
hotkeys.keys = { close = { "Escape" }, close_all = { "Super_L" } }

local function ensure_grabber_keys()
	if type(hotkeys.keys) ~= "table" then
		hotkeys.keys = {}
	end
	if type(hotkeys.keys.close) ~= "table" then
		hotkeys.keys.close = { "Escape" }
	end
	if type(hotkeys.keys.close_all) ~= "table" then
		hotkeys.keys.close_all = { "Super_L" }
	end
end

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		geometry      = { width = 800 },
		border_margin = { 10, 10, 10, 10 },
		tspace        = 5,
		delim         = "   ",
		border_width  = 2,
		ltimeout      = 0.05,
		font          = "Sans 12",
		keyfont       = "Sans bold 12",
		titlefont     = "Sans bold 14",
		is_align      = false,
		separator     = {},
		heights       = { key = 20, title = 24 },
		-- keycaps más pequeños que la descripción (fuente aparte)
		keycap_font   = nil,
		keycap_size   = 20,
		keycap_chars  = 3,
		keycap_join   = "+",
		-- truncar descripciones largas en el popup (nil = sin límite)
		description_max_len = nil,
		-- abreviar nombres de mods/teclas en recuadros
		mod_short     = {},
		key_short     = {},
		color         = { border = "#575757", text = "#aaaaaa", main = "#b1222b", wibox = "#202020",
		                  gray = "#575757", keycap_bg = "#2a2a2a", keycap_fg = "#d8d8d8" },
		shape         = nil
	}

	return redutil.table.merge(style, redutil.table.check(beautiful, "float.hotkeys") or {})
end

local function shorten_desc(text, max_len)
	if not text or not max_len or max_len < 1 then
		return tostring(text or "")
	end
	text = tostring(text)
	if #text <= max_len then
		return text
	end
	return text:sub(1, max_len - 1) .. "…"
end

local function cap_label(raw, style, is_mod)
	local s = tostring(raw or "")
	if is_mod and type(style.mod_short) == "table" and style.mod_short[s] then
		return style.mod_short[s]
	end
	if not is_mod and type(style.key_short) == "table" and style.key_short[s] then
		return style.key_short[s]
	end
	return s
end

local function fit_keycap_text(label, style)
	local s = tostring(label or "")
	local n = tonumber(style and style.keycap_chars) or 3
	n = math.max(1, n)
	if #s > n then
		return s:sub(1, n)
	end
	if #s < n then
		local pad = n - #s
		local left = math.floor(pad / 2)
		local right = pad - left
		return string.rep(" ", left) .. s .. string.rep(" ", right)
	end
	return s
end

local function keycap_wrap(label, style)
	local c = style and style.color or {}
	local bg = c.keycap_bg or c.gray or "#575757"
	local fg = c.keycap_fg or c.text or "#aaaaaa"
	local kf = (style and style.keycap_font) or (style and style.keyfont) or "Monospace 8"
	local txt = fit_keycap_text(label, style)
	return string.format(
		'<span background="%s"><span font="%s" color="%s">%s</span></span>',
		bg, kf, fg, txt
	)
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Calculate keytip length
--------------------------------------------------------------------------------
local function check_key_len(k)
	if not k or not k.key then
		return 0
	end
	local res = (tostring(k.key)):len()
	for _, v in pairs(k.mod or {}) do res = res + tostring(v):len() + 1 end
	return res
end

-- Parse raw key table
--------------------------------------------------------------------------------
local keysort = function(a, b)
	if not a or not b then
		return false
	end
	local la, lb = a.length or 0, b.length or 0
	if la ~= lb then
		return la < lb
	else
		return tostring(a.key or "") < tostring(b.key or "")
	end
end

local function parse(rawkeys, columns)
	local keys = {}
	columns = columns or 1
	if type(columns) ~= "number" or columns < 1 then
		columns = 1
	end

	local rk = {}
	if type(rawkeys) == "table" then
		for _, k in ipairs(rawkeys) do
			local n = type(k) == "table" and #k or 0
			local meta = n > 0 and k[n] or nil
			if type(meta) == "table" and meta.description then
				table.insert(rk, k)
			end
		end
	end
	local p = math.max(1, math.ceil(#rk / columns))

	-- dirty trick for raw sorting
	local sp = {}
	for _, v in ipairs(rk) do
		local nv = type(v) == "table" and #v or 0
		local mv = nv > 0 and v[nv] or nil
		if type(mv) == "table" and mv.group and not hasitem(sp, mv.group) then
			table.insert(sp, mv.group)
		end
	end
	table.sort(rk, function(a, b)
		local ma = type(a) == "table" and a[#a] or nil
		local mb = type(b) == "table" and b[#b] or nil
		local ga = type(ma) == "table" and ma.group or ""
		local gb = type(mb) == "table" and mb.group or ""
		local ai, bi = hasitem(sp, ga), hasitem(sp, gb)
		if ai ~= bi then
			return ai < bi
		else
			local ka = type(a) == "table" and a[2] or ""
			local kb = type(b) == "table" and b[2] or ""
			return tostring(ka) < tostring(kb)
		end
	end)

	-- split keys to columns
	for i = 1, columns do
		keys[i] = { groups = {}, length = nil, names = {} }
		local chunk = { unpack(rk, 1, p) }
		rk = { unpack(rk, p + 1) }

		-- build key column
		for _, v in ipairs(chunk) do
			local nv = type(v) == "table" and #v or 0
			local data = nv > 0 and v[nv] or nil
			if type(data) == "table" and data.description then
				local grp = data.group or "?"
				local k = {
					mod = v[1] or {},
					key = v[2] or "",
					description = data.description,
					group       = grp,
					keyset      = data.keyset or { v[2] },
					length      = check_key_len({ mod = v[1] or {}, key = v[2] })
				}

				if not keys[i].groups[k.group] then
					keys[i].groups[k.group] = {}
					table.insert(keys[i].names, k.group) -- sorted names list to save group order
				end
				table.insert(keys[i].groups[k.group], k)

				-- calculate max tip lenght
				if not keys[i].length or keys[i].length < k.length then keys[i].length = k.length end
			end
		end

		-- sort key by lenght inside group
		for _, group in pairs(keys[i].groups) do table.sort(group, keysort) end
	end

	return keys
end

-- Form hotkeys helper text
--------------------------------------------------------------------------------
local function build_tip(pack, style, keypressed)
	local text = {}
	if not pack or not style or not style.color or not style.heights then
		return text
	end

	for i, column in ipairs(pack) do
		local coltxt = {}
		local height = 0

		for _, name in pairs((column and column.names) or {}) do
			local group = column.groups[name]
			if group then
				-- set group title
				coltxt[#coltxt + 1] = string.format(
					'<span font="%s" color="%s">%s</span>',
					style.titlefont, style.color.gray, name
				)
				height = height + style.heights.title

				-- build key tip line
				for _, key in ipairs(group) do
					if type(key) == "table" then
						local modt = key.mod or {}

						-- key with align
						local line = cap_label(key.key, style, false)
						if style.is_align and column.length and key.length then
							--noinspection StringConcatenationInLoops
							line = line .. string.rep(" ", column.length - key.length)
						end

						local join = string.format(
							'<span font="%s" color="%s">%s</span>',
							style.keycap_font or style.keyfont or "Monospace 8",
							style.color.gray,
							style.keycap_join or "+"
						)

						-- key with mods
						if #modt > 0 then
							local fm = {}
							for _, v in ipairs(modt) do fm[#fm + 1] = keycap_wrap(cap_label(v, style, true), style) end
							table.insert(fm, keycap_wrap(line, style))
							line = table.concat(fm, join)
						else
							line = keycap_wrap(line, style)
						end

						-- key with description: tecla(s) en primera línea, descripción pequeña debajo
						local clr = keypressed and type(key.keyset) == "table" and hasitem(key.keyset, keypressed) and style.color.main or style.color.text
						local desc = shorten_desc(key.description, style.description_max_len)
						local desc_line = string.format(
							'<span font="%s" color="%s">  %s</span>',
							style.font or "Sans 10", clr, desc
						)
						coltxt[#coltxt + 1] = line .. "\n" .. desc_line
						height = height + style.heights.key * 2
					end
				end
			end
		end

		text[i] = { text = table.concat(coltxt, '\n'), height = height }
	end

	return text
end

-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function hotkeys:init()

	-- Initialize vars
	--------------------------------------------------------------------------------
	ensure_grabber_keys()
	self.keys = hotkeys.keys
	local style = default_style()
	self.style = style
	self.tip = {}

	local bm = style.border_margin
	if type(bm) ~= "table" or bm[1] == nil then
		bm = { 10, 10, 10, 10 }
		style.border_margin = bm
	end
	if type(style.color) ~= "table" then
		style.color = { border = "#575757", text = "#aaaaaa", main = "#b1222b", wibox = "#202020", gray = "#575757" }
	end
	if style.separator == nil then
		style.separator = {}
	end

	-- summary vertical size for all elements except tip textboxes
	-- used to auto adjust widget height
	self.vertical_pag = (bm[3] or 10) + (bm[4] or 10) + (style.tspace or 5) + 2
	if style.separator and style.separator.marginh then
		local mh = style.separator.marginh
		self.vertical_pag = self.vertical_pag + (mh[3] or 0) + (mh[4] or 0)
	end

	if type(style.geometry) ~= "table" then
		style.geometry = { width = 800, height = 480 }
	end

	-- Create floating wibox for top widget
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border,
		shape        = style.shape
	})

	self.wibox:geometry(style.geometry)

	-- Widget layout setup
	--------------------------------------------------------------------------------
	self.layout = wibox.layout.flex.horizontal()

	self.title = wibox.widget.textbox("Title")
	self.title:set_align("center")
	self.title:set_font(style.titlefont)

	local _, th = self.title:get_preferred_size()
	self.vertical_pag = self.vertical_pag + (th or 0)

	local subtitle = wibox.widget.textbox("Press any key to highlight tip, Escape for exit")
	subtitle:set_align("center")

	local _, sh = subtitle:get_preferred_size()
	self.vertical_pag = self.vertical_pag + (sh or 0)

	-- Separador: temas incompletos o gauge no cargado → nil index / fallo al crear widget.
	local sep_ok, sep_w = pcall(function()
		local g = redflat.gauge
		if not g or not g.separator or not g.separator.horizontal then
			return nil
		end
		return g.separator.horizontal(style.separator or {})
	end)
	if not sep_ok or sep_w == nil then
		sep_w = wibox.widget.textbox("")
		sep_w.forced_height = 1
	end

	self.wibox:setup({
		{
			{
				self.title,
				subtitle,
				sep_w,
				spacing = style.tspace,
				layout = wibox.layout.fixed.vertical,
			},
			self.layout,
			layout = wibox.layout.align.vertical,
		},
		left = bm[1], right = bm[2], top = bm[3], bottom = bm[4],
		layout = wibox.container.margin,
	})

	-- Highlight timer
	--------------------------------------------------------------------------------
	local ltimer = timer({ timeout = style.ltimeout })
	ltimer:connect_signal("timeout",
		function()
			ltimer:stop()
			hotkeys:highlight()
		end
	)

	-- Keygrabber: usa siempre la tabla del módulo `hotkeys` (no `self` del cierre: si `init`
	-- se invocara mal, `self` podría ser nil y `self.keys` falla en "attempt to index nil").
	--------------------------------------------------------------------------------
	self.keygrabber = function(_, key, event)
		ensure_grabber_keys()
		local ks = hotkeys.keys
		local close_k = ks.close
		local close_all_k = ks.close_all

		if event == "release" then
			if type(close_k) == "table" and hasitem(close_k, key) then
				hotkeys:hide(); return
			end

			if type(close_all_k) == "table" and hasitem(close_all_k, key) then
				hotkeys:hide()
				local kp = hotkeys.keypack
				local nk = type(kp) == "table" and #kp or 0
				local top = nk > 0 and kp[nk] or nil
				if top and top.on_close then top.on_close() end
				return
			end
		end

		hotkeys.lastkey = event == "press" and key or nil
		ltimer:again()
	end
end


-- Keypack managment
-----------------------------------------------------------------------------------------------------------------------

-- Set new keypack
--------------------------------------------------------------------------------
function hotkeys:set_pack(name, pack, columns, geometry, on_close)
	if not self.wibox then self:init() end

	if not self.cache[name] then
		self.cache[name] = parse(pack, columns)
	end
	if not self.cache[name] then
		self.cache[name] = {}
	end
	local geo = geometry or (self.style and self.style.geometry) or { width = 800 }
	table.insert(
		self.keypack,
		{ name = name, pack = self.cache[name], geometry = geo, on_close = on_close }
	)
	if self.title then
		self.title:set_text(tostring(name or "") .. " " .. tr("hotkeys"))
	end
	self:highlight()
	self:update_geometry(geo)
end

-- Remove current keypack
--------------------------------------------------------------------------------
function hotkeys:remove_pack()
	if not self.keypack then
		self.keypack = {}
		return
	end
	local n = #self.keypack
	if n < 1 then
		return
	end
	table.remove(self.keypack, n)
	if #self.keypack == 0 then
		if self.title then
			self.title:set_text(tr("hotkeys"))
		end
		return
	end
	local cur = self.keypack[#self.keypack]
	if not cur then
		return
	end
	if self.title then
		self.title:set_text((cur.name or "") .. " " .. tr("hotkeys"))
	end
	self:highlight()
	self:update_geometry(cur.geometry or (self.style and self.style.geometry) or { width = 800 })
end

-- Calculate and set widget height
--------------------------------------------------------------------------------
function hotkeys:update_geometry(predefined)
	if not self.wibox then
		return
	end
	predefined = predefined or (self.style and self.style.geometry) or { width = 800 }
	local w = predefined.width
	if not w then
		return
	end
	local height = 0
	for _, column in ipairs(self.tip or {}) do
		if column and column.height then
			height = math.max(height, column.height)
		end
	end
	local vp = self.vertical_pag or 0
	self.wibox:geometry({ width = w, height = predefined.height or height + vp })
end

-- Highlight key tip
--------------------------------------------------------------------------------
function hotkeys:highlight()
	if not self.layout then
		return
	end
	if not self.style then
		self.style = default_style()
	end
	if #self.keypack == 0 then
		self.tip = {}
		self.layout:reset()
		return
	end
	local kp = self.keypack[#self.keypack]
	if not kp or not kp.pack then
		self.tip = {}
		self.layout:reset()
		return
	end
	self.tip = build_tip(kp.pack, self.style, self.lastkey)

	self.layout:reset()
	for i, column in ipairs(self.tip) do
		if not self.boxes[i] then
			self.boxes[i] = wibox.widget.textbox()
			self.boxes[i]:set_valign("top")
			self.boxes[i]:set_font(self.style.font or "Sans 12")
		end

		self.boxes[i]:set_markup(column.text)
		self.layout:add(self.boxes[i])
	end
end


-- Show/hide widget
-----------------------------------------------------------------------------------------------------------------------

-- show
function hotkeys:show()
	if not self.wibox then self:init() end

	if not self.wibox.visible then
		redutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
		self.wibox.visible = true
		awful.keygrabber.run(self.keygrabber)
	-- else
	-- 	self:hide()
	end
end

-- hide
function hotkeys:hide()
	if not self.wibox then
		return
	end
	self.wibox.visible = false
	self.lastkey = nil
	self:highlight()
	awful.keygrabber.stop(self.keygrabber)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return hotkeys
