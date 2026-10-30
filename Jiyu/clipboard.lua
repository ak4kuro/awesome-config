------------------------------------------------------------------------
-----------------------------------------------
--                                              Clipboard history widget
--                          ------------------------------------------------------------------------
-----------------------------------------------
-- Historial del portapapeles con popup visual
------------------------------------------------------------------------
-----------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local L = require("Jiyu.locale").t

local clipboard = { history = {}, max_items = 20, popup = nil }

-- Añadir entrada al historial
local function add_to_history(text)
    if not text or text == "" then return end
    -- Evitar duplicados
    for i, item in ipairs(clipboard.history) do
        if item == text then
            table.remove(clipboard.history, i)
            break
        end
    end
    -- Añadir al principio
    table.insert(clipboard.history, 1, text)
    -- Limitar tamaño (reducido a 20)
    if #clipboard.history > clipboard.max_items then
        table.remove(clipboard.history)
    end
end

-- Copiar al portapapeles de forma segura (sin shell, sin inyección).
-- Escribe el texto al stdin de xclip mediante io.popen.
local function copy_to_clipboard(text)
    if not text or text == "" then return end
    local handle = io.popen("xclip -selection clipboard", "w")
    if handle then
        handle:write(text)
        handle:close()
    end
end

-- Crear popup del historial
function clipboard:show_popup()
    -- Detectar tema usando la bandera canónica scheme = "light" | "dark"
    local is_light = beautiful.color and beautiful.color.scheme == "light"
    local bg = is_light and "#ffffffee" or "#1a1a1aee"
    local border = is_light and "#c0c0c0" or "#444444"
    local text_color = is_light and "#333333" or "#e0e0e0"

    -- Cerrar popup existente
    if clipboard.popup then
        clipboard.popup.visible = false
        clipboard.popup = nil
        return
    end

    -- Crear layout
    local layout = wibox.layout.fixed.vertical()
    layout.spacing = 2

    if #clipboard.history == 0 then
        local empty = wibox.widget.textbox("  " .. L("Clipboard is empty") .. "  ")
        empty:set_font("Lato 12")
        empty:set_markup("<span color='" .. text_color .. "'>  " .. L("Clipboard is empty") .. "  </span>")
        layout:add(empty)
    else
        for i, item in ipairs(clipboard.history) do
            -- Truncar texto largo
            local display = item
            if #display > 60 then
                display = display:sub(1, 57) .. "..."
            end
            display = gears.string.xml_escape(display:gsub("\n", " ↵ "))

            local row = wibox.widget {
                {
                    {
                        markup = "<span color='" .. text_color .. "'>  " .. i .. ". " .. display .. "  </span>",
                        font = "Lato 11",
                        widget = wibox.widget.textbox,
                    },
                    left = 8, right = 8, top = 4, bottom = 4,
                    widget = wibox.container.margin,
                },
                widget = wibox.container.background,
            }

            local hover_color = is_light and "#a0a0a030" or "#55555530"
            row:connect_signal("mouse::enter", function() row.bg = hover_color end)
            row:connect_signal("mouse::leave", function() row.bg = "#00000000" end)

            row:buttons(awful.util.table.join(
                awful.button({}, 1, function()
                    copy_to_clipboard(item)
                    clipboard:hide_popup()
                end)
            ))

            layout:add(row)
        end
    end

    -- Crear popup
    local screen = awful.screen.focused()
    local workarea = screen.workarea
    local popup_width = 400
    local popup_height = math.min(#clipboard.history * 28 + 20, 400)

    clipboard.popup = wibox({
        ontop = true,
        visible = true,
        bg = bg,
        border_width = 2,
        border_color = border,
        shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 8) end,
    })

    clipboard.popup:geometry({
        x = workarea.x + (workarea.width - popup_width) / 2,
        y = workarea.y + (workarea.height - popup_height) / 2,
        width = popup_width,
        height = popup_height,
    })

    clipboard.popup:set_widget(wibox.container.margin(layout, 8, 8, 8, 8))

    clipboard.popup:buttons(awful.util.table.join(
        awful.button({}, 3, function() clipboard:hide_popup() end)
    ))
end

function clipboard:hide_popup()
    if clipboard.popup then
        clipboard.popup.visible = false
        clipboard.popup = nil
    end
end

function clipboard:toggle_popup()
    if clipboard.popup and clipboard.popup.visible then
        clipboard:hide_popup()
    else
        clipboard:show_popup()
    end
end

-- Inicializar: capturar portapapeles periódicamente (cada 5s, antes 2s)
function clipboard:init()
    local t = gears.timer({ timeout = 5 })
    t:connect_signal("timeout", function()
        awful.spawn.easy_async("xclip -selection clipboard -o 2>/dev/null", function(stdout)
            local text = stdout:gsub("\n$", "")
            if text and text ~= "" then
                add_to_history(text)
            end
        end)
    end)
    t:start()
end

return clipboard
