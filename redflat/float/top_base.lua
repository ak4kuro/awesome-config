-----------------------------------------------------------------------------------------------------------------------
--  Lista de procesos (top): instancia única CPU o RAM — wibox, selección y Kill independientes por panel              --
-----------------------------------------------------------------------------------------------------------------------

local unpack = unpack or table.unpack

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local timer = require("gears.timer")

local redutil = require("redflat.util")
local system = require("redflat.system")
local decoration = require("redflat.float.decoration")
local redtip = require("redflat.float.hotkeys")
local tr = require("redflat.util.lang").t

local M = {}

local function sort_by_cpu(a, b)
	return a.pcpu > b.pcpu
end

local function sort_by_mem(a, b)
	return a.mem > b.mem
end

local function default_style(theme_key)
	local style = {
		timeout       = 2,
		screen_gap    = 0,
		set_position  = nil,
		geometry      = { width = 460, height = 380 },
		border_margin = { 10, 10, 10, 10 },
		labels_width  = { num = 30, cpu = 70, mem = 120, action_kill = 56 },
		action_font   = "Sans 9",
		title_height  = 48,
		list_side_gap = 8,
		border_width  = 2,
		-- Botón por fila (gris); sin barra inferior
		action_button = {
			color = {
				shadow3 = "#252525",
				button  = "#4a4a4a",
				shadow4 = "#606060",
				text    = "#c8c8c8",
				pressed = "#383838",
			},
		},
		keytip        = { geometry = { width = 400 } },
		title_font    = "Sans 14 bold",
		unit          = { { "KB", -1 }, { "MB", 1024 }, { "GB", 1024^2 } },
		color         = { border = "#575757", text = "#aaaaaa", highlight = "#eeeeee", main = "#b1222b",
		                  bg = "#161616", bg_second = "#181818", wibox = "#202020" },
		shape         = nil,
		single_metric = nil,
	}
	style = redutil.table.merge(style, redutil.table.check(beautiful, "float.top") or {})
	if theme_key then
		style = redutil.table.merge(style, redutil.table.check(beautiful, theme_key) or {})
	end
	return style
end

local function construct_item(style, options)
	options = options or {}
	local item = {}
	item.label = {
		number = wibox.widget.textbox(),
		name   = wibox.widget.textbox(),
		cpu    = wibox.widget.textbox(),
		mem    = wibox.widget.textbox()
	}

	item.label.cpu:set_align("right")
	item.label.mem:set_align("right")

	local bg = style.color.bg
	local sm = style.single_metric
	local lw = style.labels_width or {}

	local mem_label_with_gap = wibox.container.margin(item.label.mem, 0, style.list_side_gap)
	local num_label_with_gap = wibox.container.margin(item.label.number, style.list_side_gap)

	local right = wibox.layout.fixed.horizontal()
	if sm == "cpu" then
		right:add(wibox.container.constraint(item.label.cpu, "exact", style.labels_width.cpu, nil))
	elseif sm == "mem" then
		right:add(wibox.container.constraint(mem_label_with_gap, "exact", style.labels_width.mem, nil))
	else
		right:add(wibox.container.constraint(item.label.cpu, "exact", style.labels_width.cpu, nil))
		right:add(wibox.container.constraint(mem_label_with_gap, "exact", style.labels_width.mem, nil))
	end

	local w_kill = lw.action_kill or 56
	if options.is_header then
		local hk = wibox.widget.textbox(tr("Kill"))
		hk:set_align("center")
		hk:set_font(style.title_font)
		right:add(wibox.container.constraint(hk, "exact", w_kill, nil))
	elseif options.on_kill then
		local kb = wibox.widget.textbox(tr("Kill"))
		kb:set_align("center")
		kb:set_font(style.action_font or "Sans 9")
		local kill_w = decoration.button(kb, options.on_kill, style.action_button)
		right:add(wibox.container.constraint(wibox.container.margin(kill_w, 3, 0, 0, 0), "exact", w_kill, nil))
	end

	local middle = wibox.layout.align.horizontal()
	middle:set_left(item.label.name)

	local left = wibox.container.constraint(num_label_with_gap, "exact", style.labels_width.num, nil)

	local item_horizontal  = wibox.layout.align.horizontal()
	item_horizontal:set_left(left)
	item_horizontal:set_middle(middle)
	item_horizontal:set_right(right)
	item.layout = wibox.container.background(item_horizontal, bg)

	function item:set_bg(color)
		bg = color
		item.layout:set_bg(color)
	end

	function item:set_select()
		item.layout:set_bg(style.color.main)
		item.layout:set_fg(style.color.highlight)
	end

	function item:set_unselect()
		item.layout:set_bg(bg)
		item.layout:set_fg(style.color.text)
	end

	function item:set(args)
		if args.number then item.label.number:set_text(args.number) end
		if args.name then item.label.name:set_text(args.name) end
		if args.cpu then item.label.cpu:set_text(args.cpu) end
		if args.mem then item.label.mem:set_text(args.mem) end
		if args.pid then item.pid = args.pid end
	end

	return item
end

local function list_construct(n, style, select_function, after_action)
	local list = {}
	local list_layout = wibox.layout.flex.vertical()
	list.layout = wibox.container.background(list_layout, style.color.bg)
	list.items = {}
	for i = 1, n do
		local item
		item = construct_item(style, {
			on_kill = function()
				if item.pid then
					awful.spawn.with_shell("kill " .. item.pid)
					if after_action then after_action() end
				end
			end,
		})
		list.items[i] = item
		item:set({ number = i})
		item:set_bg((i % 2) == 1 and style.color.bg or style.color.bg_second)
		list_layout:add(item.layout)
		item.layout:buttons(awful.util.table.join(
			awful.button({ }, 1, function() select_function(i) end)
		))
	end
	return list
end

function M.new(opts)
	opts = opts or {}
	local theme_key = opts.theme_key
	local fixed_sort = opts.fixed_sort or "cpu"
	local tip_title = opts.tip_title or tr("Top process")
	local peer_module = opts.peer_module

	local self = { keys = {}, _fake_keys = {} }

	if peer_module then
		self._close_other = function()
			local ok, peer = pcall(require, peer_module)
			if ok and peer and peer.hide then peer:hide() end
		end
	end

	self.keys.action = {
		{
			{}, "k", function() self.kill_selected() end,
			{ description = tr("Kill process"), group = tr("Action") }
		},
		{
			{}, "Escape", function() self:hide() end,
			{ description = tr("Close top list widget"), group = tr("Action") }
		},
		{
			{ "Mod4" }, "F1", function() redtip:show() end,
			{ description = tr("Show hotkeys helper"), group = tr("Action") }
		},
	}

	self.keys.management = {}
	self.keys.all = awful.util.table.join(self.keys.management, self.keys.action)

	self._fake_keys = {
		{
			{}, "N", nil,
			{ description = tr("Select process by key"), group = tr("Management"),
			  keyset = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } }
		},
	}

	function self:init()
		local number_of_lines = 9
		local selected = {}
		local cpu_storage = { cpu_total = {}, cpu_active = {} }
		local style = default_style(theme_key)
		style.single_metric = (fixed_sort == "mem") and "mem" or "cpu"
		self.style = style

		local sort_function
		local title
		local toplist

		local function select_item(i)
			if selected.number and selected.number ~= i then toplist.items[selected.number]:set_unselect() end
			toplist.items[i]:set_select()
			selected.pid = toplist.items[i].pid
			selected.number = i
		end

		function self:set_sort(args)
			if args == "cpu" then
				sort_function = sort_by_cpu
			elseif args == "mem" then
				sort_function = sort_by_mem
			end
		end

		function self.kill_selected()
			if selected.number then awful.spawn.with_shell("kill " .. selected.pid) end
			self:update_list()
		end

		self.keygrabber = function(mod, key, event)
			if     event ~= "press" then return end
			for _, k in ipairs(self.keys.all) do
				if redutil.key.match_grabber(k, mod, key) then k[3](); return end
			end
			if string.match("123456789", key) then select_item(tonumber(key)) end
		end

		title = construct_item(style, { is_header = true })
		title:set_bg("transparent")
		if style.single_metric == "cpu" then
			title:set({ number = "#", name = tr("Process Name"), cpu = "CPU %", mem = "" })
		else
			title:set({ number = "#", name = tr("Process Name"), cpu = "", mem = tr("Memory") })
		end

		for _, txtbox in pairs(title.label) do
			txtbox:set_font(style.title_font)
		end

		toplist = list_construct(number_of_lines, style, select_item, function()
			self:update_list()
		end)

		function self:update_list()
			local proc = system.proc_info(cpu_storage)
			table.sort(proc, sort_function)

			if selected.number then
				toplist.items[selected.number]:set_unselect()
				selected.number = nil
			end

			for i = 1, number_of_lines do
				local p = proc[i]
				if p then
					toplist.items[i]:set({
						name = p.name,
						cpu = string.format("%.1f", p.pcpu * 100),
						mem = redutil.text.dformat(p.mem, style.unit, 2, " "),
						pid = p.pid
					})

					if selected.pid and selected.pid == p.pid then
						toplist.items[i]:set_select()
						selected.number = i
					end
				else
					toplist.items[i]:set({
						name = "—",
						cpu = "",
						mem = "",
						pid = nil
					})
				end
			end
		end

		local area = wibox.layout.align.vertical()
		area:set_top(wibox.container.constraint(title.layout, "exact", nil, style.title_height))
		area:set_middle(toplist.layout)
		local list_layout = wibox.container.margin(area, unpack(style.border_margin))

		self.wibox = wibox({
			ontop        = true,
			bg           = style.color.wibox,
			border_width = style.border_width,
			border_color = style.color.border,
			shape        = style.shape
		})

		self.wibox:set_widget(list_layout)
		self.wibox:geometry(style.geometry)

		redutil.float_autohide.attach(self, self.wibox, {
			hide = function()
				self:hide()
			end,
		})

		self.update_timer = timer({timeout = style.timeout})
		self.update_timer:connect_signal("timeout", function() self:update_list() end)

		self:set_keys()
		self:set_sort(fixed_sort)
		self:update_list()
	end

	function self:hide()
		if not self.wibox then return end
		self.wibox.visible = false
		self.update_timer:stop()
		awful.keygrabber.stop(self.keygrabber)
		-- No usamos redtip:set_pack/remove_pack aquí: apilaba sobre el pack «Main» y provocaba errores
		-- en hotkeys.lua; los atajos siguen activos vía keygrabber (k, Esc, F1 → redtip:show).
	end

	function self:show()
		if not self.wibox then self:init() end
		if self.wibox.visible then
			self:hide()
		else
			if self._close_other then self._close_other() end
			self:update_list()

			if self.style.set_position then
				self.style.set_position(self.wibox)
			else
				awful.placement.under_mouse(self.wibox)
			end
			redutil.placement.no_offscreen(self.wibox, self.style.screen_gap, screen[mouse.screen].workarea)

			redutil.float_autohide.stop(self)
			self.wibox.visible = true
			self.update_timer:start()
			awful.keygrabber.run(self.keygrabber)
		end
	end

	function self:set_keys(keys, layout)
		layout = layout or "all"
		if keys then
			self.keys[layout] = keys
			if layout ~= "all" then self.keys.all = awful.util.table.join(self.keys.management, self.keys.action) end
		end
		self.tip = awful.util.table.join(self.keys.all, self._fake_keys)
	end

	return self
end

return M
