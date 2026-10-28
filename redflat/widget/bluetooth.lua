-----------------------------------------------------------------------------------------------------------------------
--                                        RedFlat Bluetooth panel widget                                             --
-----------------------------------------------------------------------------------------------------------------------

local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local table = table
local type = type
local unpack = unpack or table.unpack

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")

local tooltip = require("redflat.float.tooltip")
local redutil = require("redflat.util")
local svgbox = require("redflat.gauge.svgbox")
local tr = require("redflat.util.lang").t

local bt = { mt = {} }

local FETCH = "sh -c 'bluetoothctl show 2>/dev/null; echo ---SEP---; (bluetoothctl devices Paired 2>/dev/null || bluetoothctl paired-devices 2>/dev/null); echo ---SEP---; bluetoothctl devices Connected 2>/dev/null; echo ---SEP---; bluetoothctl devices 2>/dev/null'"

-- Caché de batería por MAC (último valor conocido)
local _battery_cache = {}

local function fetch_battery(mac)
	if not mac or mac == "" then return nil end
	local cmd = string.format("bluetoothctl info %s 2>/dev/null", mac)
	-- awful.util.pread está deprecado en Awesome 4.3 y no ejecuta el comando;
	-- usar io.popen directamente.
	local handle = io.popen(cmd)
	if not handle then return nil end
	local out = handle:read("*a")
	handle:close()
	if not out or out == "" then return nil end
	-- bluetoothctl reporta la batería en hex (0x64) o decimal (100);
	-- a veces incluye el valor decimal entre paréntesis: "0x64 (100)"
	local pct_hex = out:match("Battery Percentage:%s*(0x%x+)")
	local pct_dec = out:match("Battery Percentage:%s*0x%x+%s*%((%d+)%)")
	                     or out:match("Battery Percentage:%s*(%d+)$")
	local val = nil
	if pct_dec then
		val = tonumber(pct_dec)
	elseif pct_hex then
		val = tonumber(pct_hex)  -- Lua interpreta 0x.. como hex
	end
	if val then
		_battery_cache[mac] = val
		return val
	end
	return _battery_cache[mac] or nil
end

local function default_style()
	local style = {
		icon = redutil.base.placeholder(),
		geometry = { width = 440, height = 520 },
		border_margin = { 14, 14, 12, 12 },
		border_width = 0,
		row_spacing = 4,
		screen_gap = 0,
		set_position = nil,
		shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 12) end,
		fonts = {
			title   = "Sans bold 12",
			section = "Sans 8",
			row     = "Sans 11",
			hint    = "Sans 9",
		},
		color = {
			main      = "#b1222b",
			icon      = "#a0a0a0",
			gray      = "#383838",
			wibox     = "#1c1c1cf0",
			border    = "#333333",
			text      = "#aaaaaa",
			highlight = "#ffffff",
			bg        = "#161616",
			bg_second = "#252525",
			muted     = "#555555",
			sep       = "#2e2e2e",
		},
		tooltip = {},
		scan_interval = 12,
		scan_seconds = 22,
		manager_cmd = nil,
		labels = {
			on = tr("Bluetooth on"),
			off = tr("Bluetooth off"),
			no_adapter = tr("Bluetooth unavailable"),
			power_on = tr("Turn Bluetooth on"),
			power_off = tr("Turn Bluetooth off"),
			scan_pair = tr("Scan and pair"),
			scanning = tr("Scanning…"),
			section_paired = tr("Paired devices"),
			section_nearby = tr("Discovered (tap to pair)"),
			empty = tr("No paired devices"),
			empty_nearby = tr("None; use «Scan and pair»"),
			manager = tr("Open Bluetooth manager…"),
		},
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.bluetooth") or {})
end

local function split_fetch4(out)
	if not out then
		return "", "", "", ""
	end
	local p1, r = out:match("^(.-)%-%-%-SEP%-%-%-(.*)$")
	if not p1 then
		return out, "", "", ""
	end
	local p2, r2 = r:match("^(.-)%-%-%-SEP%-%-%-(.*)$")
	if not p2 then
		return p1, r, "", ""
	end
	local p3, p4 = r2:match("^(.-)%-%-%-SEP%-%-%-(.*)$")
	if not p3 then
		return p1, p2, r2, ""
	end
	return p1, p2, p3, p4 or ""
end

local function parse_powered(show_out)
	for line in show_out:gmatch("[^\r\n]+") do
		local v = line:match("^%s*Powered:%s*(%S+)")
		if v then
			return v == "yes"
		end
	end
	return false
end

local function parse_device_lines(block)
	local list = {}
	local seen = {}
	for line in block:gmatch("[^\r\n]+") do
		local mac, name = line:match("^Device%s+([%x:]+)%s+(.+)$")
		if mac and not seen[mac] then
			seen[mac] = true
			list[#list + 1] = { mac = mac, name = name }
		end
	end
	return list
end

local function parse_connected_set(block)
	local set = {}
	for line in block:gmatch("[^\r\n]+") do
		local mac = line:match("^Device%s+([%x:]+)")
		if mac then
			set[mac] = true
		end
	end
	return set
end

local function xml_esc(s)
	s = tostring(s or "")
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function layout_clear(layout)
	if not layout then
		return
	end
	local ok = pcall(function()
		layout:reset()
	end)
	if ok then
		return
	end
	local ch = layout.get_children and layout:get_children() or layout.children
	if type(ch) == "table" then
		for i = #ch, 1, -1 do
			pcall(function()
				layout:remove(i)
			end)
		end
	end
end

function bt:_connected_count()
	local n = 0
	for _ in pairs(self._connected) do
		n = n + 1
	end
	return n
end

function bt:_tooltip_text()
	local L = self.style.labels
	local n = self:_connected_count()
	if not self._has_adapter then
		return L.no_adapter
	end
	if not self._powered then
		return L.off
	end
	if n > 0 then
		-- Incluir nombre y batería de cada dispositivo conectado
		local parts = {}
		for _, d in ipairs(self._paired or {}) do
			if self._connected[d.mac] then
				local name = d.name or d.mac
				if #name > 28 then name = name:sub(1, 25) .. "…" end
				local batt = fetch_battery(d.mac)
				if batt then
					table.insert(parts, string.format("%s · %d%%", name, batt))
				else
					table.insert(parts, name)
				end
			end
		end
		if #parts > 0 then
			return tr("Bluetooth") .. ": " .. table.concat(parts, " | ")
		end
		return n == 1 and tr("Bluetooth: 1 connected") or string.format(tr("Bluetooth: %d connected"), n)
	end
	return L.on
end

function bt:_sync_icon_color()
	if not self._icon_widg then
		return
	end
	local c = self.style.color
	-- Encendido → main; apagado o sin adaptador → icon (blanco en JiyuLight)
	if self._has_adapter and self._powered then
		self._icon_widg:set_color(c.main)
	else
		self._icon_widg:set_color(c.icon or c.gray)
	end
end

function bt:_apply_parse(out)
	local show, paired, conn, alldev = split_fetch4(out)
	if show:match("No default controller") then
		self._has_adapter = false
		self._powered = false
		self._paired = {}
		self._connected = {}
		self._all_devices = {}
		return
	end
	self._has_adapter = true
	self._powered = parse_powered(show)
	self._paired = parse_device_lines(paired)
	self._connected = parse_connected_set(conn)
	self._all_devices = parse_device_lines(alldev)
end

function bt:refresh_panel_if_open()
	if self.wibox and self.wibox.visible then
		self:populate_panel()
	end
end

function bt:refresh_state_only()
	awful.spawn.easy_async(FETCH, function(out)
		self:_apply_parse(out)
		self:_sync_icon_color()
		if self._tp then
			self._tp:set_text(self:_tooltip_text())
		end
	end)
end

function bt:refresh_state_and_menu()
	awful.spawn.easy_async(FETCH, function(out)
		self:_apply_parse(out)
		self:_sync_icon_color()
		if self._tp then
			self._tp:set_text(self:_tooltip_text())
		end
		self:refresh_panel_if_open()
	end)
end

function bt:start_device_scan()
	if not self._has_adapter or not self._powered or self._scanning then
		return
	end
	self._scanning = true
	local sec = tonumber(self.style.scan_seconds) or 22
	-- Mantener el escaneo activo durante N segundos reales.
	local shell = string.format(
		"bash -lc 'bluetoothctl --timeout 3 scan on >/dev/null 2>&1; sleep %d; bluetoothctl --timeout 3 scan off >/dev/null 2>&1'",
		sec
	)
	awful.spawn.easy_async_with_shell(shell, function()
		self._scanning = false
		if self._scan_poll then
			self._scan_poll:stop()
		end
		self:refresh_state_and_menu()
	end)
	if self._scan_poll then
		self._scan_poll:stop()
	end
	self._scan_poll = gears.timer({ timeout = 2.5 })
	self._scan_poll:connect_signal("timeout", function()
		if not self._scanning then
			self._scan_poll:stop()
			return
		end
		awful.spawn.easy_async(FETCH, function(out)
			self:_apply_parse(out)
			self:_sync_icon_color()
			if self._tp then
				self._tp:set_text(self:_tooltip_text())
			end
			self:refresh_panel_if_open()
		end)
	end)
	self._scan_poll:start()
	self:refresh_panel_if_open()
end

function bt:add_heading(markup)
	local c = self.style.color
	local icon_path = self.style.panel_icon
			or (beautiful.path and beautiful.path .. "/widget/bluetooth.svg")
			or (awful.util.get_configuration_dir() .. "themes/Jiyu/widget/bluetooth.svg")
	local icon_w
	pcall(function()
		icon_w = wibox.widget({
			image  = icon_path,
			resize = true,
			forced_width  = 14,
			forced_height = 14,
			widget = wibox.widget.imagebox,
		})
	end)
	local tb = wibox.widget.textbox()
	tb:set_markup(markup)
	tb:set_font(self.style.fonts.title)
	tb.valign = "center"
	local row = wibox.layout.fixed.horizontal()
	row.spacing = 6
	if icon_w then row:add(wibox.container.place(icon_w)) end
	row:add(tb)
	self.main_layout:add(wibox.container.margin(row, 0, 0, 0, 2))
	local sep = wibox.widget({
		forced_height = 1,
		widget        = wibox.widget.separator,
		orientation   = "horizontal",
		color         = (c and c.sep) or "#2e2e2e",
		span_ratio    = 1.0,
		thickness     = 1,
	})
	self.main_layout:add(wibox.container.margin(sep, 0, 0, 0, 6))
end

function bt:add_section_title(text)
	local c = self.style.color
	local tb = wibox.widget.textbox()
	tb:set_markup('<span color="' .. c.main .. '" letter_spacing="800">' .. xml_esc(text:upper()) .. "</span>")
	tb:set_font(self.style.fonts.section)
	self.main_layout:add(wibox.container.margin(tb, 0, 0, 8, 3))
end

function bt:add_hint(text)
	local tb = wibox.widget.textbox()
	tb:set_markup('<span color="' .. self.style.color.gray .. '">' .. xml_esc(text) .. "</span>")
	tb:set_font(self.style.fonts.hint)
	self.main_layout:add(wibox.container.margin(tb, 0, 0, 4, 0))
end

function bt:add_text_row(markup)
	local tb = wibox.widget.textbox()
	tb:set_markup(markup)
	tb:set_font(self.style.fonts.row)
	local bg = wibox.container.background(wibox.container.margin(tb, 6, 6, 3, 3), self.style.color.bg or "#161616")
	self.main_layout:add(bg)
end

function bt:add_action_row(markup, on_click)
	local c = self.style.color
	local bg_n = c.bg_second or "#252525"
	local tb = wibox.widget.textbox()
	tb:set_markup(markup)
	tb:set_font(self.style.fonts.row)
	local inner = wibox.container.margin(tb, 8, 8, 5, 5)
	local bg = wibox.container.background(
		inner, bg_n,
		function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end
	)
	bg:buttons(awful.button({}, 1, on_click))
	bg:connect_signal("mouse::enter", function()
		bg:set_bg(c.main .. "cc")
	end)
	bg:connect_signal("mouse::leave", function()
		bg:set_bg(bg_n)
	end)
	self.main_layout:add(wibox.container.margin(bg, 0, 0, 0, 2))
end

function bt:add_button(label, on_click)
	local c = self.style.color
	local bg_n = c.bg_second or "#252525"
	local tb = wibox.widget.textbox()
	tb:set_font(self.style.fonts.hint)
	tb:set_markup('<span color="' .. (c.muted or "#555555") .. '">' .. xml_esc(type(label) == "string" and label or tostring(label)) .. '</span>')
	tb.align  = "center"
	tb.valign = "center"
	local btn = wibox.container.background(
		wibox.container.margin(tb, 10, 10, 4, 4),
		bg_n,
		function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end
	)
	btn:buttons(awful.button({}, 1, on_click))
	btn:connect_signal("mouse::enter", function()
		tb:set_markup('<span color="' .. (c.highlight or "#ffffff") .. '">' .. xml_esc(type(label) == "string" and label or tostring(label)) .. '</span>')
		btn:set_bg(c.gray)
	end)
	btn:connect_signal("mouse::leave", function()
		tb:set_markup('<span color="' .. (c.muted or "#555555") .. '">' .. xml_esc(type(label) == "string" and label or tostring(label)) .. '</span>')
		btn:set_bg(bg_n)
	end)
	self.main_layout:add(wibox.container.margin(btn, 0, 0, 6, 2))
end

function bt:populate_panel()
	local L = self.style.labels
	layout_clear(self.main_layout)

	self:add_heading('<span color="' .. (self.style.color.highlight or "#eeeeee") .. '">' .. tr("Bluetooth") .. "</span>")

	if not self._has_adapter then
		self:add_text_row('<span color="' .. (self.style.color.icon or "#a0a0a0") .. '">' .. xml_esc(L.no_adapter) .. "</span>")
		return
	end

	self:add_section_title(tr("State"))
	self:add_text_row('<span color="' .. (self.style.color.text or "#aaaaaa") .. '">' .. xml_esc(self:_tooltip_text()) .. "</span>")

	self:add_section_title(tr("Management"))
	self:add_action_row('<span color="' .. (self.style.color.text or "#aaaaaa") .. '">' .. xml_esc(L.power_on) .. "</span>", function()
		awful.spawn({ "bluetoothctl", "power", "on" }, false)
		gears.timer.start_new(1.2, function()
			self:refresh_state_and_menu()
		end)
	end)
	self:add_action_row('<span color="' .. (self.style.color.text or "#aaaaaa") .. '">' .. xml_esc(L.power_off) .. "</span>", function()
		awful.spawn({ "bluetoothctl", "power", "off" }, false)
		gears.timer.start_new(1.2, function()
			self:refresh_state_and_menu()
		end)
	end)
	self:add_action_row(
		'<span color="' .. (self.style.color.text or "#aaaaaa") .. '">' .. xml_esc(self._scanning and L.scanning or L.scan_pair) .. "</span>",
		function()
			if self._powered and not self._scanning then
				self:start_device_scan()
			end
		end
	)

	local paired_list = self._paired
	if #paired_list == 0 and self._all_devices and #self._all_devices > 0 then
		local fallback = {}
		for _, d in ipairs(self._all_devices) do
			if self._connected[d.mac] then
				fallback[#fallback + 1] = d
			end
		end
		if #fallback > 0 then
			paired_list = fallback
		end
	end

	self:add_section_title(L.section_paired)
	if #paired_list == 0 then
		self:add_text_row('<span color="' .. (self.style.color.icon or "#a0a0a0") .. '">' .. xml_esc(L.empty) .. "</span>")
	else
		for _, d in ipairs(paired_list) do
			local is_conn = self._connected[d.mac]
			local title = d.name
			if #title > 42 then
				title = title:sub(1, 39) .. "…"
			end
			local row = (is_conn and "✓ " or "") .. title
			if is_conn then
				local batt = fetch_battery(d.mac)
				if batt then
					row = row .. string.format("  · %d%%", batt)
				end
			end
			self:add_action_row('<span color="' .. (self.style.color.text or "#aaaaaa") .. '">' .. xml_esc(row) .. "</span>", function()
				if is_conn then
					awful.spawn({ "bluetoothctl", "disconnect", d.mac }, false)
				else
					awful.spawn({ "bluetoothctl", "connect", d.mac }, false)
				end
				gears.timer.start_new(2, function()
					self:refresh_state_and_menu()
				end)
			end)
		end
	end

	local paired_macs = {}
	for _, d in ipairs(paired_list) do
		paired_macs[d.mac] = true
	end
	local nearby = {}
	for _, d in ipairs(self._all_devices or {}) do
		if not paired_macs[d.mac] then
			nearby[#nearby + 1] = d
		end
	end

	self:add_section_title(L.section_nearby)
	if #nearby == 0 then
		self:add_text_row('<span color="' .. (self.style.color.icon or "#a0a0a0") .. '">' .. xml_esc(L.empty_nearby) .. "</span>")
	else
		for _, d in ipairs(nearby) do
			local title = d.name
			if #title > 42 then
				title = title:sub(1, 39) .. "…"
			end
			self:add_action_row('<span color="' .. (self.style.color.text or "#aaaaaa") .. '">' .. xml_esc(title) .. "</span>", function()
				awful.spawn.easy_async_with_shell(
					string.format(
						"bluetoothctl pair %s && bluetoothctl trust %s && bluetoothctl connect %s",
						d.mac,
						d.mac,
						d.mac
					),
					function()
						gears.timer.start_new(2.5, function()
							self:refresh_state_and_menu()
						end)
					end
				)
			end)
		end
	end

	if self.style.manager_cmd and type(self.style.manager_cmd) == "string" and self.style.manager_cmd ~= "" then
		self:add_button(L.manager, function()
			awful.spawn(self.style.manager_cmd, false)
		end)
	end

	self:add_button(tr("Refresh list"), function()
		self:refresh_state_and_menu()
	end)
end

function bt:hide_panel()
	redutil.float_autohide.stop(self)
	if self.wibox then
		self.wibox.visible = false
	end
	pcall(function()
		awful.keygrabber.stop(self.keygrabber)
	end)
end

function bt:toggle_menu()
	if not self.wibox then
		return
	end
	if self.wibox.visible then
		self:hide_panel()
		return
	end

	local scr = mouse.screen
	if type(scr) == "number" then
		scr = screen[scr]
	end
	if not scr and awful.screen and awful.screen.focused then
		scr = awful.screen.focused()
	end
	if not scr and screen[1] then
		scr = screen[1]
	end
	if scr then
		self.wibox.screen = scr
	end

	local wa = scr and scr.workarea or (screen[1] and screen[1].workarea)
	if self.style.set_position then
		self.style.set_position(self.wibox)
	else
		awful.placement.under_mouse(self.wibox)
	end
	if wa then
		redutil.placement.no_offscreen(self.wibox, self.style.screen_gap, wa)
	end

	redutil.float_autohide.stop(self)
	self.wibox.visible = true
	awful.keygrabber.run(self.keygrabber)
	layout_clear(self.main_layout)
	self:add_heading('<span color="' .. (self.style.color.highlight or "#eeeeee") .. '">' .. tr("Bluetooth") .. "</span>")
	self:refresh_state_and_menu()
end

function bt:init(args)
	if self.wibox then
		return
	end
	self.style = redutil.table.merge(default_style(), args or {})

	self._has_adapter = false
	self._powered = false
	self._paired = {}
	self._connected = {}
	self._all_devices = {}
	self._scanning = false
	self._scan_poll = nil
	self._icon_widg = nil
	self._tp = nil

	self.main_layout = wibox.layout.fixed.vertical()
	self.main_layout.spacing = self.style.row_spacing

	self.wibox = wibox({
		ontop = true,
		bg = self.style.color.wibox or "#202020",
		border_width = self.style.border_width,
		border_color = self.style.color.border or "#575757",
		shape = self.style.shape,
	})
	self.wibox:set_widget(wibox.container.margin(self.main_layout, unpack(self.style.border_margin)))
	self.wibox:geometry(self.style.geometry)

	self.keygrabber = function(_, key, event)
		if event ~= "press" then
			return
		end
		if key == "Escape" then
			self:hide_panel()
		end
	end

	redutil.float_autohide.attach(self, self.wibox, {
		hide = function()
			self:hide_panel()
		end,
		can_hide = function()
			return true
		end,
	})

	gears.timer({
		timeout = self.style.scan_interval,
		autostart = true,
		call_now = false,
		callback = function()
			bt:refresh_state_only()
		end,
	})

	gears.timer.delayed_call(function()
		bt:refresh_state_only()
	end)
end

function bt.new(user_style)
	user_style = user_style or {}
	if not bt.wibox then
		bt:init(user_style)
	elseif next(user_style) then
		bt.style = redutil.table.merge(bt.style, user_style)
	end

	local icon = svgbox(bt.style.icon)
	icon:set_color(bt.style.color.icon or bt.style.color.gray)
	bt._icon_widg = icon

	local layout = wibox.layout.fixed.horizontal()
	layout:add(icon)

	bt._tp = tooltip({ objects = { layout } }, bt.style.tooltip)

	bt:refresh_state_only()
	return layout
end

function bt.mt:__call(...)
	return bt.new(...)
end

return setmetatable(bt, bt.mt)
