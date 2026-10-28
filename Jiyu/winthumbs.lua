------------------------------------------------------------------------
-----------------------------------------------
--                                           Window thumbnails hover bar
--                          ------------------------------------------------------------------------
-----------------------------------------------
-- Muestra una barra de miniaturas reales (c.content) al acercar el ratón al borde inferior del panel.
-- Uso: require("Jiyu.winthumbs"):init({ screen = s })
------------------------------------------------------------------------
-----------------------------------------------
local awful     = require("awful")
local wibox     = require("wibox")
local gears     = require("gears")
local beautiful = require("beautiful")
local cairo     = require("lgi").cairo

local winthumbs = {}

-- ── Caché de capturas (weak keys para permitir GC de clientes cerrados) ──
local _snapshot = setmetatable({}, { __mode = "k" })
winthumbs._snapshot = _snapshot

local _last_capture_time = setmetatable({}, { __mode = "k" })
local CAPTURE_THROTTLE = 1.0 -- segundos mínimos entre capturas de la misma ventana

-- Tamaño máximo de miniatura para reducir memoria
local MAX_THUMB_W = 320
local MAX_THUMB_H = 180

local function capture(c, force)
    if not c or not c.valid then return nil end
    if not force then
        local now = os.clock()
        local last = _last_capture_time[c]
        if last and (now - last) < CAPTURE_THROTTLE and _snapshot[c] then
            return _snapshot[c]
        end
        _last_capture_time[c] = now
    end
    local ok, img = pcall(function()
        local g = c:geometry()
        if g.width <= 0 or g.height <= 0 then return nil end
        -- Escalar a miniatura para ahorrar memoria
        local scale = math.min(MAX_THUMB_W / g.width, MAX_THUMB_H / g.height, 1.0)
        local tw = math.max(1, math.floor(g.width * scale))
        local th = math.max(1, math.floor(g.height * scale))
        local dst = cairo.ImageSurface(cairo.Format.ARGB32, tw, th)
        local cr  = cairo.Context(dst)
        local src = gears.surface(c.content)
        cr:scale(scale, scale)
        cr:set_source_surface(src, 0, 0)
        cr:paint()
        src:finish()  -- liberar surface source explícitamente
        cr = nil       -- soltar contexto
        return dst
    end)
    return (ok and img) and img or nil
end

local function save_snapshot(c)
    -- Liberar surface anterior si existe
    local old = _snapshot[c]
    if old then
        old:finish()
        _snapshot[c] = nil
    end
    local s = capture(c, true)
    if s then _snapshot[c] = s end
end

-- Captura periódica de ventanas visibles (cada 5 s) para tener snapshot reciente
local _snap_timer = gears.timer({
    timeout  = 5,
    callback = function()
        for _, c in ipairs(client.get()) do
            if not c.minimized and not c.hidden then
                save_snapshot(c)
            end
        end
        -- Forzar garbage collection periódico
        collectgarbage("step", 512)
    end,
})
_snap_timer:start()

-- Guarda snapshot justo antes de minimizar
client.connect_signal("property::minimized", function(c)
    if c.minimized then
        save_snapshot(c)
    end
end)

-- Limpia caché cuando la ventana se cierra
client.connect_signal("unmanage", function(c)
    local surf = _snapshot[c]
    if surf then
        surf:finish()
        _snapshot[c] = nil
    end
    _last_capture_time[c] = nil
end)

-- ── Configuración ────────────────────────────────────────────────────
local function default_cfg()
    local cfg = {
        height        = 120,
        thumb_w       = 180,
        thumb_h       = 100,
        spacing       = 8,
        padding       = 10,
        bg            = "#d0d0d0f2",
        border        = "#b0b0b0",
        label_font    = "Sans 9",
        label_fg      = "#000000",
        label_fg_focus= "#000000",
        thumb_bg      = "#c8c8c8",
        thumb_bg_focus= "#b8b8b8",
        radius        = 10,
        hide_delay    = 1.2,
        trigger_px    = 4,
        fade_step     = 0.06,
        fade_interval = 0.012,
    }
    local ok, bt_over = pcall(function() return beautiful.float and beautiful.float.winthumbs end)
    if ok and bt_over then
        for k, v in pairs(bt_over) do cfg[k] = v end
    end
    return cfg
end
local CFG = default_cfg()

-- ── Estado interno ───────────────────────────────────────────────────
local _bars = {}

-- ── Activa un cliente (desminimiza si hace falta) ────────────────────
local function activate(c)
    if not c or not c.valid then return end
    if c.minimized then c.minimized = false end
    if not c:isvisible() then
        awful.tag.viewmore(c:tags(), c.screen)
    end
    client.focus = c
end

-- ── Canvas para dibujar una miniatura ────────────────────────────────
local function make_canvas(w, h)
    local canvas = wibox.widget.base.make_widget()
    canvas._surface = nil

    function canvas:set_surface(surf)
        canvas._surface = surf
        canvas:emit_signal("widget::redraw_needed")
    end

    function canvas:draw(_, _, cr, width, height)
        local _surf = canvas._surface
        if not _surf then
            cr:set_source_rgba(0.82, 0.82, 0.82, 1)
            cr:paint()
            return
        end
        local sw = _surf:get_width()
        local sh = _surf:get_height()
        if sw <= 0 or sh <= 0 then return end
        local scale = math.min(w / sw, h / sh)
        local ox = (w - sw * scale) / 2
        local oy = (h - sh * scale) / 2
        cr:save()
        cr:translate(ox, oy)
        cr:scale(scale, scale)
        cr:set_source_surface(_surf, 0, 0)
        cr:paint()
        cr:restore()
    end

    return canvas
end

-- ── Widget de una miniatura individual ───────────────────────────────
local function make_thumb_widget(c, thumb_w, thumb_h, label_font, label_fg, label_fg_focus, thumb_bg, thumb_bg_focus)
    local canvas = make_canvas(thumb_w, thumb_h)

    local lbl = wibox.widget {
        widget = wibox.widget.textbox,
        font   = label_font,
        align  = "center",
        valign = "center",
    }

    local is_focused = (client.focus == c)
    lbl:set_markup(string.format('<span color="%s">%s</span>',
        is_focused and label_fg_focus or label_fg,
        awful.util.escape((c.name or "?"):sub(1, 24))
    ))

    local bg_color = is_focused and (thumb_bg_focus or "#b8b8b8") or (thumb_bg or "#c8c8c8")
    local container = wibox.widget {
        {
            {
                {
                    canvas,
                    forced_width  = thumb_w,
                    forced_height = thumb_h,
                    widget        = wibox.container.constraint,
                },
                lbl,
                layout  = wibox.layout.fixed.vertical,
                spacing = 2,
            },
            margins = 4,
            widget  = wibox.container.margin,
        },
        bg     = bg_color,
        shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end,
        widget = wibox.container.background,
    }

    local function refresh()
        local surf = (not c.minimized) and capture(c) or nil
        if not surf then surf = _snapshot[c] end
        if surf then canvas:set_surface(surf) end
    end
    refresh()

    container:buttons(awful.util.table.join(
        awful.button({}, 1, function() activate(c) end),
        awful.button({}, 3, function() if c.valid then c:kill() end end)
    ))

    local function on_enter()
        if mouse.coords().buttons[1] then activate(c) end
    end
    container:connect_signal("mouse::enter", on_enter)
    canvas:connect_signal("mouse::enter",    on_enter)

    return container, refresh
end

-- ── Construcción/actualización del wibox ─────────────────────────────
local function rebuild(bar)
    local s     = bar.screen
    local geo   = s.geometry
    local style = bar.style

    local clients = {}
    for _, c in ipairs(client.get()) do
        if c.screen == s
           and not c.skip_taskbar
           and not c.hidden
           and c.type ~= "desktop"
           and c.type ~= "dock"
           and c.type ~= "splash"
        then
            table.insert(clients, c)
        end
    end

    if #clients == 0 then
        bar.wibox.visible = false
        return
    end

    local row = wibox.layout.fixed.horizontal()
    row.spacing = style.spacing
    bar._refreshers = {}

    for _, c in ipairs(clients) do
        local ok, w, refresh = pcall(make_thumb_widget,
            c,
            style.thumb_w, style.thumb_h,
            style.label_font, style.label_fg, style.label_fg_focus,
            style.thumb_bg, style.thumb_bg_focus
        )
        if ok and w then
            row:add(w)
            table.insert(bar._refreshers, refresh)
        end
    end

    bar.wibox:setup {
        {
            row,
            halign = "center",
            valign = "center",
            widget = wibox.container.place,
        },
        margins = style.padding,
        widget  = wibox.container.margin,
    }
end

-- ── Show / hide (con fade in/out) ────────────────────────────────────
local function stop_fade(bar)
    if bar._fade_timer then
        bar._fade_timer:stop()
        bar._fade_timer = nil
    end
end

local function fade_to(bar, target, on_done)
    stop_fade(bar)
    local step = bar.style.fade_step or 0.06
    local interval = bar.style.fade_interval or 0.012
    bar._fade_timer = gears.timer({ timeout = interval })
    bar._fade_timer:connect_signal("timeout", function()
        local cur = bar.wibox.opacity or 1
        local nxt = cur + (target > cur and step or -step)
        if (target > cur and nxt >= target) or (target < cur and nxt <= target) then
            nxt = target
        end
        bar.wibox.opacity = nxt
        if nxt == target then
            stop_fade(bar)
            if on_done then on_done() end
        end
    end)
    bar._fade_timer:start()
end

local function show_bar(bar)
    if bar._hide_timer then bar._hide_timer:stop() end
    rebuild(bar)
    local geo = bar.screen.geometry
    local h   = bar.style.height
    bar.wibox:geometry({
        x      = geo.x,
        y      = geo.y + geo.height - h - (beautiful.panel_height or 40),
        width  = geo.width,
        height = h,
    })
    bar.wibox.opacity = 0
    bar.wibox.visible = true
    fade_to(bar, 1)
end

local function hide_bar(bar)
    if bar._hide_timer then bar._hide_timer:stop() end
    bar._hide_timer = gears.timer.start_new(bar.style.hide_delay, function()
        fade_to(bar, 0, function()
            bar.wibox.visible = false
        end)
        return false  -- timer de un solo disparo
    end)
end

winthumbs.show = show_bar

-- ── Init público ─────────────────────────────────────────────────────
function winthumbs:init(args)
    args = args or {}
    local s = args.screen or screen.primary

    local style = {
        height        = args.height        or CFG.height,
        thumb_w       = args.thumb_w       or CFG.thumb_w,
        thumb_h       = args.thumb_h       or CFG.thumb_h,
        spacing       = args.spacing       or CFG.spacing,
        padding       = args.padding       or CFG.padding,
        bg            = args.bg            or CFG.bg,
        border        = args.border        or CFG.border,
        label_font    = args.label_font    or CFG.label_font,
        label_fg      = args.label_fg      or CFG.label_fg,
        label_fg_focus= args.label_fg_focus or CFG.label_fg_focus,
        thumb_bg      = args.thumb_bg      or CFG.thumb_bg,
        thumb_bg_focus= args.thumb_bg_focus or CFG.thumb_bg_focus,
        radius        = args.radius        or CFG.radius,
        hide_delay    = args.hide_delay    or CFG.hide_delay,
        trigger_px    = args.trigger_px    or CFG.trigger_px,
        fade_step     = args.fade_step     or CFG.fade_step,
        fade_interval = args.fade_interval or CFG.fade_interval,
    }

    local geo = s.geometry
    local ph  = beautiful.panel_height or 40

    local wb = wibox({
        x            = geo.x,
        y            = geo.y + geo.height - style.height - ph,
        width        = geo.width,
        height       = style.height,
        bg           = style.bg,
        border_width = 1,
        border_color = style.border,
        ontop        = true,
        visible      = false,
        shape        = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, style.radius)
        end,
    })

    local bar = {
        wibox      = wb,
        screen     = s,
        style      = style,
        _refreshers= {},
    }
    _bars[s] = bar

    wb:connect_signal("mouse::enter", function() show_bar(bar) end)
    wb:connect_signal("mouse::leave", function() hide_bar(bar) end)

    client.connect_signal("manage",            function() if wb.visible then rebuild(bar) end end)
    client.connect_signal("unmanage",          function() if wb.visible then rebuild(bar) end end)
    client.connect_signal("property::name",    function() if wb.visible then rebuild(bar) end end)
    client.connect_signal("property::minimized", function() if wb.visible then rebuild(bar) end end)
    client.connect_signal("focus",             function() if wb.visible then rebuild(bar) end end)

    return bar
end

------------------------------------------------------------------------
-----------------------------------------------
return winthumbs
