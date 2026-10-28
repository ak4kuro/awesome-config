------------------------------------------------------------------------
-----------------------------------------------
--                                                   CPU graph widget
--                          ------------------------------------------------------------------------
-----------------------------------------------
-- Gráfico de CPU en tiempo real usando redflat.gauge.graph.line
------------------------------------------------------------------------
-----------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local cpugraph = { widget = nil, timer = nil }

-- Estado para cálculo de CPU (diferencial entre lecturas)
local prev_total = 0
local prev_idle  = 0

-- Función para obtener uso de CPU leyendo /proc/stat directamente (sin spawn)
local function get_cpu_usage()
    local f = io.open("/proc/stat", "r")
    if not f then return 0 end
    local line = f:read("*l")
    f:close()
    if not line then return 0 end
    -- Formato: cpu  user nice system idle iowait irq softirq
    local values = {}
    for v in line:gmatch("%d+") do
        table.insert(values, tonumber(v) or 0)
    end
    if #values < 4 then return 0 end
    local idle  = values[4] + (values[5] or 0)
    local total = 0
    for _, v in ipairs(values) do total = total + v end
    local diff_total = total - prev_total
    local diff_idle  = idle - prev_idle
    prev_total = total
    prev_idle  = idle
    if diff_total <= 0 then return 0 end
    return ((diff_total - diff_idle) / diff_total) * 100
end

-- Crear el widget
function cpugraph.new(args)
    args = args or {}
    local update_interval = args.update_interval or 2 -- 2 segundos (antes 1s)

    local graph = require("redflat.gauge.graph.line")
    local widget = graph.new({
        max_value = 100,
        step = 0.05,
        color = {
            main = beautiful.color and beautiful.color.main or "#0066CC",
            gray = beautiful.color and beautiful.color.gray or "#d0d0d0",
        },
    })

    local function update()
        local cpu_usage = get_cpu_usage()
        widget:add_value(cpu_usage)
    end

    local timer = gears.timer {
        timeout = update_interval,
        autostart = true,
        callback = update
    }

    return widget
end

return cpugraph
