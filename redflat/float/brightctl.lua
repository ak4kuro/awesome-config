-----------------------------------------------------------------------------------------------------------------------
--  RedFlat: control de brillo con barra deslizante. Posición fija (theme.float.brightctl.set_position).               --
--  Autocierre tras N s con el ratón fuera (float_autohide). Clic de nuevo en el icono del panel → show() cierra.      --
-----------------------------------------------------------------------------------------------------------------------

local math = math
local tonumber = tonumber
local unpack = unpack or table.unpack

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local wibox_base = require("wibox.widget.base")
local naughty = require("naughty")

local redutil = require("redflat.util")
local tr = require("redflat.util.lang").t

local brightctl = {}

-- Misma lectura que redflat/widget/backlight.lua
-- Filtrar por clase backlight real; fallback a xrandr si no hay hardware
local READ_PCT = [[bash -lc 'if command -v brightnessctl >/dev/null 2>&1; then c=$(brightnessctl -c backlight get 2>/dev/null); m=$(brightnessctl -c backlight max 2>/dev/null); if [ -n "$m" ] && [ "$m" -gt 0 ]; then echo $((c*100/m)); exit 0; fi; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); echo $(( (cur*100 + max/2) / max )); exit 0; fi; cur=$(xrandr --verbose 2>/dev/null | grep -m1 "Brightness:" | awk "{print \$2}"); if [ -n "$cur" ]; then echo $(awk "BEGIN{printf \"%d\", $cur*100}"); exit 0; fi; echo NO_DEVICE']]

local function parse_pct_line(out)
	if not out then
		return nil
	end
	local line = out:match("^%s*(.-)%s*$") or ""
	if line == "NO_DEVICE" then
		return nil
	end
	return tonumber(line:match("^(%d+)"))
end

local function set_brightness_shell(p)
	p = math.max(0, math.min(100, math.floor(tonumber(p) or 0)))
	return string.format(
		[=[bash -lc 'p=%d; [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100; if command -v brightnessctl >/dev/null 2>&1; then brightnessctl -c backlight set "${p}%%" >/dev/null 2>&1 && exit 0; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); new=$(( (p*max+50)/100 )); [ "$new" -lt 0 ] && new=0; [ "$new" -gt "$max" ] && new=$max; echo "$new" > "$d/brightness" 2>/dev/null; exit 0; fi; val=$(awk "BEGIN{print $p/100}"); for o in $(xrandr --query 2>/dev/null | grep " connected" | awk "{print \$1}"); do xrandr --output "$o" --brightness "$val" 2>/dev/null; done']=],
		p
	)
end

local function default_style()
	local style = {
		geometry      = { width = 320, height = 120 },
		max_width     = 400,
		max_height    = 220,
		min_width     = 280,
		min_height    = 100,
		border_margin = { 14, 14, 12, 12 },
		border_width  = 0,
		row_spacing   = 8,
		screen_gap    = 0,
		set_position  = nil,
		autohide_timeout = nil,
		shape         = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 12) end,
		shape_clip    = false,
		icon          = nil,
		slider = {
			bar_height          = 6,
			handle_width        = 18,
			forced_height       = 30,
			track_width         = 180,
			bar_margins         = { top = 6, bottom = 6 },
			handle_border_width = 0,
			handle_color        = nil,
			handle_border_color = nil,
			bar_color           = nil,
			bar_active_color    = nil,
			handle_margins      = nil,
		},
		button_size = 30,
		button_step = 5,
		fonts = {
			hint  = "Sans 9",
			pct   = "Sans bold 12",
			title = "Sans 9",
		},
		color = {
			border    = "#333333",
			wibox     = "#1c1c1cee",
			text      = "#aaaaaa",
			main      = "#b1222b",
			highlight = "#ffffff",
			gray      = "#383838",
			bg        = "#161616",
			bg_alt    = "#252525",
			muted     = "#555555",
			sep       = "#303030",
		},
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "float.brightctl") or {})
end

function brightctl:set_panel_widget(w)
	self._panel = w
end

-- Callback personalizado para establecer brillo absoluto (pct 0-100)
-- Si está definido, se usa en lugar del comando shell
function brightctl:set_brightness_callback(fn)
	self._brightness_callback = fn
end

-- Callback personalizado para leer brillo absoluto (devuelve pct 0-100)
function brightctl:get_brightness_callback(fn)
	self._get_brightness_callback = fn
end

function brightctl:fit_context()
	local s = self.wibox and self.wibox.screen or awful.screen.focused() or screen[1]
	return { screen = s, dpi = beautiful.xresources.get_dpi() }
end

function brightctl:resize_to_content()
	if not self.wibox or not self.main_layout then
		return
	end
	local m = self.style.border_margin
	local bw = self.style.border_width or 0
	local inner_max_w = self.style.max_width or 280
	local inner_max_h = self.style.max_height or 160
	local iw, ih = 180, 50
	local ok, fw, fh = pcall(function()
		return wibox_base.fit_widget(self:fit_context(), self.main_layout, inner_max_w, inner_max_h)
	end)
	if ok and fw and fh then
		iw, ih = fw, fh
	end
	local total_w = iw + m[1] + m[2] + 2 * bw
	local total_h = ih + m[3] + m[4] + 2 * bw
	local max_tw = inner_max_w + m[1] + m[2] + 2 * bw
	local max_th = inner_max_h + m[3] + m[4] + 2 * bw
	total_w = math.max(self.style.min_width or 196, math.min(max_tw, total_w))
	total_h = math.max(self.style.min_height or 58, math.min(max_th, total_h))
	self.wibox.width = total_w
	self.wibox.height = total_h
	if self.style.shape and self.style.shape_clip == false then
		self.wibox.shape_clip = nil
	end
	if self.wibox.visible then
		local wa = self.wibox.screen and self.wibox.screen.workarea
		if wa then
			if self.style.set_position then
				self.style.set_position(self.wibox)
			end
			redutil.placement.no_offscreen(self.wibox, self.style.screen_gap or 0, wa)
		end
	end
end

local function make_btn(label, color_main, color_bg, size, font, on_click)
	local tb = wibox.widget.textbox()
	tb:set_font(font)
	tb:set_markup('<span color="' .. color_main .. '"><b>' .. label .. '</b></span>')
	tb.align  = "center"
	tb.valign = "center"
	local btn = wibox.container.background(
		wibox.container.place(tb),
		color_bg,
		function(cr, w, h) gears.shape.circle(cr, w, h) end
	)
	btn.forced_width  = size
	btn.forced_height = size
	btn:connect_signal("button::press", function(_, _, _, b)
		if b == 1 then
			btn.bg = color_main .. "66"
			on_click()
			gears.timer.start_new(0.12, function() btn.bg = color_bg; return false end)
		end
	end)
	btn:connect_signal("mouse::enter", function()
		btn.bg = color_main .. "44"
	end)
	btn:connect_signal("mouse::leave", function()
		btn.bg = color_bg
	end)
	return btn
end

local function make_sep(color)
	local sep = wibox.widget({
		forced_height = 1,
		widget        = wibox.widget.separator,
		orientation   = "horizontal",
		color         = color or "#303030",
		span_ratio    = 1.0,
		thickness     = 1,
	})
	return wibox.container.margin(sep, 0, 0, 4, 4)
end

function brightctl:init()
	if self.wibox then
		return
	end
	self.style = default_style()
	self.main_layout = wibox.layout.fixed.vertical()
	self.main_layout.spacing = self.style.row_spacing

	self.err_tb = wibox.widget.textbox()
	self.err_tb:set_font(self.style.fonts.hint)
	self.err_tb:set_markup('<span color="' .. self.style.color.muted .. '">' .. tr("No backlight device") .. "</span>")
	local err_wrap = wibox.container.margin(self.err_tb, 4, 4, 2, 2)
	err_wrap:set_visible(false)

	local c        = self.style.color
	local main_red  = c.main
	local track_gray = c.gray or "#383838"
	local inner_max = self.style.max_width or 400
	local sl   = self.style.slider or {}
	local bsz  = self.style.button_size or 30
	local bstp = self.style.button_step or 5
	local tw   = math.max(100, math.min(sl.track_width or 180, inner_max - bsz * 2 - 32))
	local bar_m = sl.bar_margins or { top = 6, bottom = 6 }
	local pct_font   = (self.style.fonts and self.style.fonts.pct)   or "Sans bold 12"
	local title_font = (self.style.fonts and self.style.fonts.title) or "Sans 9"
	local btn_font   = "Sans bold 11"

	-- ── Cabecera: [icono☀] BRILLO  (línea completa) ──
	local icon_w
	local icon_path = self.style.icon or (beautiful.path and beautiful.path .. "/widget/brightness.svg")
					or (awful.util.get_configuration_dir() .. "themes/Jiyu/widget/brightness.svg")
	local ok_icon = pcall(function()
		icon_w = wibox.widget({
			image  = icon_path,
			resize = true,
			forced_width  = 14,
			forced_height = 14,
			widget = wibox.widget.imagebox,
		})
	end)
	if not ok_icon then icon_w = nil end

	local title_tb = wibox.widget.textbox()
	title_tb:set_font(title_font)
	title_tb:set_markup('<span color="' .. (c.text or "#aaaaaa") .. '" letter_spacing="1200">' .. tr("BRILLO") .. '</span>')
	title_tb.align  = "center"
	title_tb.valign = "center"

	-- Fila título: icono (opcional) + texto centrado en toda la fila
	local title_row = wibox.layout.align.horizontal()
	if icon_w then
		title_row:set_left(wibox.container.margin(wibox.container.place(icon_w), 0, 4, 0, 0))
	end
	title_row:set_middle(wibox.container.place(title_tb))

	-- ── Porcentaje grande centrado ──
	self._pct_tb = wibox.widget.textbox()
	self._pct_tb:set_font(pct_font)
	self._pct_tb:set_markup('<span color="' .. (c.highlight or "#ffffff") .. '">50%</span>')
	self._pct_tb.align  = "center"
	self._pct_tb.valign = "center"
	local pct_row = wibox.container.place(self._pct_tb)
	pct_row.halign = "center"

	-- ── Separador ──
	local sep = make_sep(c.sep or "#303030")

	-- ── Slider ──
	self.slider = wibox.widget({
		bar_margins         = bar_m,
		bar_height          = sl.bar_height or 6,
		handle_width        = sl.handle_width or 18,
		forced_height       = sl.forced_height or 30,
		forced_width        = tw,
		bar_color           = sl.bar_color or track_gray,
		bar_active_color    = sl.bar_active_color or main_red,
		handle_color        = sl.handle_color or main_red,
		handle_border_color = sl.handle_border_color or (c.bg_alt or "#252525"),
		handle_border_width = sl.handle_border_width or 0,
		handle_margins      = sl.handle_margins,
		bar_shape           = gears.shape.rounded_bar,
		handle_shape        = gears.shape.circle,
		minimum = 0,
		maximum = 100,
		value   = 50,
		widget  = wibox.widget.slider,
	})

	-- ── Botones circulares ──
	local btn_bg = c.bg_alt or "#252525"

	local btn_dec = make_btn("−", main_red, btn_bg, bsz, btn_font, function()
		local v = math.max(0, math.floor(self.slider.value) - bstp)
		self._ignore_slider = true
		self.slider:set_value(v)
		self._ignore_slider = false
		self._pending_pct = v
		self._apply_timer:stop()
		self._apply_timer:again()
		if self._pct_tb then
			self._pct_tb:set_markup('<span color="' .. (c.highlight or "#ffffff") .. '">' .. v .. '%</span>')
		end
	end)

	local btn_inc = make_btn("+", main_red, btn_bg, bsz, btn_font, function()
		local v = math.min(100, math.floor(self.slider.value) + bstp)
		self._ignore_slider = true
		self.slider:set_value(v)
		self._ignore_slider = false
		self._pending_pct = v
		self._apply_timer:stop()
		self._apply_timer:again()
		if self._pct_tb then
			self._pct_tb:set_markup('<span color="' .. (c.highlight or "#ffffff") .. '">' .. v .. '%</span>')
		end
	end)

	local place_slider = wibox.container.place(self.slider)
	place_slider.valign = "center"
	place_slider.halign = "center"

	-- Fila slider: [−] [========] [+]  con margen entre botón y barra
	local row = wibox.layout.align.horizontal()
	row:set_left(wibox.container.margin(wibox.container.place(btn_dec), 0, 6, 0, 0))
	row:set_middle(place_slider)
	row:set_right(wibox.container.margin(wibox.container.place(btn_inc), 6, 0, 0, 0))

	-- Layout vertical: título / porcentaje / sep / fila slider
	local vbox = wibox.layout.fixed.vertical()
	vbox.spacing = 0
	vbox:add(title_row)
	vbox:add(pct_row)
	vbox:add(sep)
	vbox:add(row)

	self._content_root = vbox

	self._apply_timer = gears.timer({
		timeout = 0.05,
		autostart = false,
		single_shot = true,
	})
	self._apply_timer:connect_signal("timeout", function()
		local v = self._pending_pct
		if v == nil or not self.wibox or not self.wibox.visible then
			return
		end
		-- Si hay callback personalizado (xrandr), usarlo directamente
		if self._brightness_callback then
			self._brightness_callback(v)
			if self._panel and self._panel.update_brightness then
				pcall(function()
					self._panel:update_brightness()
				end)
			end
			return
		end
		awful.spawn.easy_async_with_shell(set_brightness_shell(v), function()
			if self._panel and self._panel.update_brightness then
				pcall(function()
					self._panel:update_brightness()
				end)
			end
		end)
	end)

	self.slider:connect_signal("property::value", function()
		if self._ignore_slider then
			return
		end
		local v = math.floor(self.slider.value)
		self._pending_pct = v
		if self._pct_tb then
			self._pct_tb:set_markup('<span color="' .. (self.style.color.highlight or "#ffffff") .. '">' .. v .. '%</span>')
		end
		self._apply_timer:stop()
		self._apply_timer:again()
	end)

	self._slider_wrap = self._content_root

	self.main_layout:add(err_wrap)
	self.main_layout:add(self._slider_wrap)

	self._err_wrap = err_wrap

	self.wibox = wibox({
		ontop = true,
		bg = self.style.color.wibox,
		border_width = self.style.border_width,
		border_color = self.style.color.border,
		shape = self.style.shape,
	})
	self.wibox:set_widget(wibox.container.margin(self.main_layout, unpack(self.style.border_margin)))
	self.wibox:geometry(self.style.geometry)

	local function brightctl_clear_shape_clip()
		if self.wibox and self.style.shape and self.style.shape_clip == false then
			self.wibox.shape_clip = nil
		end
	end
	self.wibox:connect_signal("property::geometry", brightctl_clear_shape_clip)
	brightctl_clear_shape_clip()

	self.keygrabber = function(_, key, event)
		if event ~= "press" then
			return
		end
		if key == "Escape" then
			self:hide()
		end
	end

	redutil.float_autohide.attach(self, self.wibox, {
		timeout = self.style.autohide_timeout,
		hide = function()
			self:hide()
		end,
		can_hide = function()
			return true
		end,
	})
end

function brightctl:_sync_slider_from_hw()
	-- Si hay callback de lectura, usarlo
	if self._get_brightness_callback then
		local pct = self._get_brightness_callback()
		if not self.wibox then return end
		self._ignore_slider = true
		if pct == nil then
			self._slider_wrap:set_visible(false)
			self._err_wrap:set_visible(true)
		else
			pct = math.min(100, math.max(0, pct))
			self._err_wrap:set_visible(false)
			self._slider_wrap:set_visible(true)
			self.slider:set_value(pct)
			if self._pct_tb then
				self._pct_tb:set_markup('<span color="' .. (self.style.color.highlight or "#ffffff") .. '">' .. pct .. '%</span>')
			end
		end
		self._ignore_slider = false
		gears.timer.delayed_call(function()
			if self.wibox then self:resize_to_content() end
		end)
		return
	end
	awful.spawn.easy_async_with_shell(READ_PCT, function(o)
		if not self.wibox then
			return
		end
		local pct = parse_pct_line(o)
		self._ignore_slider = true
		if pct == nil then
			self._slider_wrap:set_visible(false)
			self._err_wrap:set_visible(true)
		else
			pct = math.min(100, math.max(0, pct))
			self._err_wrap:set_visible(false)
			self._slider_wrap:set_visible(true)
			self.slider:set_value(pct)
			if self._pct_tb then
				self._pct_tb:set_markup('<span color="' .. (self.style.color.highlight or "#ffffff") .. '">' .. pct .. '%</span>')
			end
		end
		self._ignore_slider = false
		gears.timer.delayed_call(function()
			if self.wibox then
				self:resize_to_content()
			end
		end)
	end)
end

function brightctl:hide()
	redutil.float_autohide.stop(self)
	if self.wibox then
		self.wibox.visible = false
	end
	if self._apply_timer then
		self._apply_timer:stop()
	end
	pcall(function()
		awful.keygrabber.stop(self.keygrabber)
	end)
end

function brightctl:show()
	if not self.wibox then
		self:init()
	end
	if self.wibox.visible then
		self:hide()
		return
	end

	local scr = awful.screen.focused()
	if not scr then
		local ms = mouse.screen
		if type(ms) == "number" then
			scr = screen[ms]
		else
			scr = ms
		end
	end
	if not scr and screen[1] then
		scr = screen[1]
	end
	local wa = scr and scr.workarea

	if scr then
		self.wibox.screen = scr
	end

	pcall(function()
		if self.style.set_position then
			self.style.set_position(self.wibox)
		elseif scr then
			local w = scr.workarea
			self.wibox:geometry({ x = w.x + w.width, y = w.y + w.height })
		end
	end)
	if wa then
		redutil.placement.no_offscreen(self.wibox, self.style.screen_gap, wa)
	end

	redutil.float_autohide.stop(self)
	self.wibox.visible = true
	awful.keygrabber.run(self.keygrabber)
	self:_sync_slider_from_hw()
end

return brightctl
