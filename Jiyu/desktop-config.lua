-----------------------------------------------------------------------------------------------------------------------
--                                               Desktop widgets config                                              --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local beautiful = require("beautiful")
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local redflat = require("redflat")
local redutil = require("redflat.util")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local desktop = {}

-- desktop aliases
local wgeometry = redflat.util.desktop.wgeometry
local system = redflat.system

-- Desktop widgets
-----------------------------------------------------------------------------------------------------------------------
function desktop:init(args)
	if not beautiful.desktop then return end
	if not redutil.table.check(beautiful, "individual.desktop") then return end

	local scr = screen.primary or screen[1]
	if not scr then return end

	args = args or {}
	local attempt = args._attempt or 1
	local workarea = scr.workarea
	-- Al arranque algunos drivers dan workarea 0×0 un instante; sin geometría los widgets no se ven.
	if (workarea.width < 120 or workarea.height < 120) and attempt < 5 then
		local next_args = {}
		for k, v in pairs(args) do
			next_args[k] = v
		end
		next_args._attempt = attempt + 1
		gears.timer.delayed_call(function()
			desktop:init(next_args)
		end)
		return
	end

	local wa = workarea

	local env = args.env or {}
	local autohide = env.desktop_autohide or false

	-- Dos columnas (dos líneas verticales), 8 filas; margen horizontal centrado
	local grid_src = beautiful.desktop.grid or {}
	local grid = redutil.table.merge({}, grid_src)
	if not grid.width or not grid.width[2] then
		grid.width = { 400, 400 }
	end
	local nrows = 8
	grid.height = {}
	for i = 1, nrows do
		grid.height[i] = 56
	end
	local wa0 = workarea
	local cols_w = grid.width[1] + grid.width[2]
	local gap_cols = 40
	local m = math.floor((wa0.width - cols_w - gap_cols) / 2)
	if m < 8 then
		m = math.max(8, math.floor((wa0.width - cols_w) / 2))
	end
	grid.edge = redutil.table.merge({}, grid_src.edge or {})
	if not grid.edge.height or not grid.edge.height[1] then
		grid.edge.height = { 72, 72 }
	end
	grid.edge.width = { m, m }

	local rl, rr = 0, 0
	local function next_left()
		rl = rl + 1
		return { 1, rl }
	end
	local function next_right()
		rr = rr + 1
		return { 2, rr }
	end

	local net_storage = {}
	local net_iface = system.default_net_interface()
	local net_max = 6 * 1024 * 1024
	local net_unit = { { "B/s", -1 }, { "K/s", 1024 }, { "M/s", 1024 * 1024 } }

	-- Network speed: dos widgets separados (subida y bajada)
	--------------------------------------------------------------------------------
	local net_up = { geometry = wgeometry(grid, next_left(), workarea) }
	-- DOWN en la columna derecha para equilibrar visualmente ambas columnas.
	local net_down = { geometry = wgeometry(grid, next_right(), workarea) }

	local net_cache = { time = 0, up = 0, down = 0 }
	local function read_net_cached()
		local now = os.time()
		if net_cache.time ~= now then
			local t = system.net_speed(net_iface, net_storage)
			net_cache.up = t[1] or 0
			net_cache.down = t[2] or 0
			net_cache.time = now
		end
		return net_cache.up, net_cache.down
	end

	net_up.args = {
		sensors = {
			{
				meter_function = function()
					local up = read_net_cached()
					local txt = redutil.text.dformat(up, net_unit, 2, "")
					return { up, up, text = txt }
				end,
				maxm = net_max,
				crit = net_max * 0.8,
				name = "up",
			},
		},
		timeout = 2,
	}

	net_down.args = {
		sensors = {
			{
				meter_function = function()
					local _, down = read_net_cached()
					local txt = redutil.text.dformat(down, net_unit, 2, " ")
					return { down, down, text = txt }
				end,
				maxm = net_max,
				crit = net_max * 0.8,
				name = "down",
			},
		},
		timeout = 2,
	}

	net_up.style = redutil.table.merge(
		beautiful.individual.desktop.multiline.netline,
		{
			-- UP con flecha hacia arriba (no down.svg).
			icon = { image = beautiful.path .. "/desktop/up.svg", margin = { 0, 6, 0, 0 } },
			lines = {
				spacing = 0,
			},
		}
	)
	net_down.style = redutil.table.merge(
		beautiful.individual.desktop.multiline.netline,
		{
			lines = {
				spacing = 0,
			},
		}
	)

	-- CPU: multímetro con una barra vertical por núcleo
	--------------------------------------------------------------------------------
	local cpu_storage = { cpu_total = {}, cpu_active = {} }
	local ncores = math.max(1, system.cpu_core_count())
	local cpuwidget = { geometry = wgeometry(grid, next_left(), workarea) }

	cpuwidget.args = {
		topbars = { num = ncores, maxm = 100, crit = 90 },
		lines   = false,
		meter   = { args = cpu_storage, func = system.dformatted.cpu_only },
		timeout = 5,
	}

	cpuwidget.style = redutil.table.merge(
		beautiful.individual.desktop.multimeter.cpu,
		{
			upbar = {
				width = math.max(18, math.min(30, math.floor(360 / ncores))),
				chunk = { num = 8, line = 4, shape = "plain" },
			},
			height = { upright = 48, lines = 0 },
		}
	)

	local ramw = { geometry = wgeometry(grid, next_left(), workarea) }
	ramw.args = {
		sensors = {
			{ meter_function = system.desktop_ram_usage, maxm = 100, crit = 80, name = "ram" },
		},
		timeout = 5,
	}
	ramw.style = redutil.table.merge(
		beautiful.individual.desktop.multiline.ramone,
		{
			lines = {
				show = { label = false, text = false, tooltip = true },
			},
		}
	)

	local swapw = { geometry = wgeometry(grid, next_left(), workarea) }
	swapw.args = {
		sensors = {
			{ meter_function = system.desktop_swap_usage, maxm = 100, crit = 80, name = "swap" },
		},
		timeout = 5,
	}
	swapw.style = redutil.table.merge(
		beautiful.individual.desktop.multiline.swapone,
		{
			lines = {
				show = { label = false, text = false, tooltip = true },
			},
		}
	)

	-- Discos: root y /home por separado (texto = usado / total GB · %)
	--------------------------------------------------------------------------------
	local disk_root = { geometry = wgeometry(grid, next_left(), workarea) }
	disk_root.args = {
		sensors = {
			{ meter_function = function() return system.desktop_fs_usage("/") end, maxm = 100, crit = 85, name = "root" },
		},
		timeout = 120,
	}
	disk_root.style = redutil.table.merge(
		beautiful.individual.desktop.multiline.diskline,
		{
			lines = {
				-- root sin nombre ni números (solo barra + tooltip)
				show = { label = false, text = false, tooltip = true },
			},
		}
	)

	local disk_home = { geometry = wgeometry(grid, next_left(), workarea) }
	disk_home.args = {
		sensors = {
			{ meter_function = function() return system.desktop_fs_usage("/home") end, maxm = 100, crit = 85, name = "home" },
		},
		timeout = 120,
	}
	disk_home.style = redutil.table.merge(
		beautiful.individual.desktop.multiline.diskline,
		{
			lines = {
				-- home ocupando todo el ancho útil (sin label/valor en línea).
				show = { label = false, text = false, tooltip = true },
			},
		}
	)

	-- Sensors parser setup
	--------------------------------------------------------------------------------
	local sensors_base_timeout = 10

	system.lmsensors.delay = 2
	system.lmsensors.patterns = {
		-- Tu placa nct6795: CPUTIN es la temperatura del CPU
		cpu       = { match = "CPUTIN:%s+%+(%d+)%.%d°[CF]" },
		-- Fallback genérico
		cpu_core  = { match = "PECI Agent 0:%s+%+(%d+)%.?%d*°[CF]" },
		wifi      = {
			match = {
				"iwlwifi_1%-virtual%-0\r?\nAdapter:%sVirtual%sdevice\r?\ntemp1:%s+%+(%d+)%.?%d*",
				"iwlwifi[^\n]+\nAdapter:[^\n]+\n%s*temp1:%s+%+(%d+)%.?%d*",
				"iwlwifi[^\n]+\n[^\n]+\n%s*temp1:%s+%+(%d+)%.?%d*",
			},
		},
		-- Tu placa: fan2 es el único que funciona
		cpu_fan   = {
			match = {
				"fan2:%s+(%d+)%sRPM",
				"fan1:%s+(%d+)%sRPM",
				"Processor%sFan:%s+(%d+)%sRPM",
			},
		},
	}

	-- start auto async lmsensors check
	system.lmsensors:soft_start(sensors_base_timeout)

	-- Temperatura CPU (CPUTIN)
	--------------------------------------------------------------------------------
	local thermal_disk = { geometry = wgeometry(grid, next_right(), workarea) }
	thermal_disk.args = {
		sensors = {
			{ meter_function = system.lmsensors.get, args = "cpu", maxm = 100, crit = 75, name = "core" },
		},
		timeout = sensors_base_timeout,
	}
	thermal_disk.style = beautiful.individual.desktop.multiline.thermal_core

	-- Fan speed (fan2 — muestra OFF cuando lee 0, placa sin sensor fiable)
	--------------------------------------------------------------------------------
	local fan = { geometry = wgeometry(grid, next_right(), workarea) }
	fan.args = {
		sensors = {
			{
				meter_function = function()
					local v = system.lmsensors.get("cpu_fan")
					local rpm = v[1] or 0
					if rpm == 0 then
						return { 0, 0, off = true, text = "OFF" }
					end
					return { rpm, rpm, text = string.format("%d RPM", rpm) }
				end,
				maxm = 5000,
				crit = 4000,
				name = "fan",
			},
		},
		timeout = sensors_base_timeout,
	}
	fan.style = beautiful.individual.desktop.multiline.fan

	-- vnstat: una línea tráfico diario, otra mensual
	--------------------------------------------------------------------------------
	local vnstat_daily   = system.vnstat_check({ options = "-d", traffic = "total", interface = net_iface })
	local vnstat_monthly = system.vnstat_check({ options = "-m", traffic = "total", interface = net_iface })

	local vnstat_d = { geometry = wgeometry(grid, next_right(), workarea) }
	vnstat_d.args = {
		sensors = {
			{ async_function = vnstat_daily, maxm = 5 * 1024^3, name = "day" },
		},
		timeout = 900,
	}
	vnstat_d.style = beautiful.individual.desktop.multiline.vnstat

	local vnstat_m = { geometry = wgeometry(grid, next_right(), workarea) }
	vnstat_m.args = {
		sensors = {
			{ async_function = vnstat_monthly, maxm = 75 * 1024^3, name = "month" },
		},
		timeout = 900,
	}
	vnstat_m.style = beautiful.individual.desktop.multiline.vnstat

	-- Calendar (borde derecho)
	--------------------------------------------------------------------------------
	local cwidth  = 140  -- calendar widget width
	local cmargin = 0    -- margen respecto al borde derecho
	local cy = 21        -- calendar widget upper margin
	local cheight = wa.height - 2*cy

	local calendar = {
		args     = { timeout = 60 },
		geometry = {
			x      = wa.x + wa.width - cwidth - cmargin,
			y      = wa.y + cy,
			width  = cwidth,
			height = cheight,
		}
	}

	-- Initialize all desktop widgets
	--------------------------------------------------------------------------------
	-- Barra MPRIS centrada: justo debajo de las filas root y home (fila 7 de la cuadrícula).
	local bar_h = 64
	local bar_w = math.min(720, math.max(360, workarea.width - 96))
	local row_below_disks = wgeometry(grid, { 1, 7 }, workarea)
	local playerbar_y = workarea.y + row_below_disks.y + 6
	local playerbar_w = {
		geometry = {
			x = workarea.x + math.floor((workarea.width - bar_w) / 2),
			y = playerbar_y,
			width = bar_w,
			height = bar_h,
		},
		transparent_bg = false,
		args = {},
		style = redutil.table.merge(beautiful.desktop.playerbar or {}, beautiful.individual.desktop.playerbar or {}),
	}
	playerbar_w.body = redflat.desktop.playerbar(playerbar_w.args, playerbar_w.style)

	-- Widget de clima (debajo del playerbar) - una línea simple
	-- Para fijar la ciudad manualmente, cambia WEATHER_CITY abajo
	-- Si está vacío (""), se detecta automáticamente por IP
	local WEATHER_CITY = "Bilbao" -- Ej: "Madrid", "Barcelona", "Sevilla"

	local weather_y = playerbar_y + bar_h + 6
	local weather_w = {
		geometry = {
			x = workarea.x + math.floor((workarea.width - bar_w) / 2),
			y = weather_y,
			width = bar_w,
			height = bar_h,
		},
		transparent_bg = true,
	}
	-- Crear widget de texto simple para clima
	local weather_text = wibox.widget.textbox()
	weather_text:set_font("Sans 14")
	weather_text:set_align("center")

	-- Escapar caracteres Pango/XML en texto para set_markup
	local function escape_markup(s)
		return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
	end

	-- Funcion para actualizar el texto del widget
	local function update_weather_text(city, wout)
		local weather = wout:gsub("\n", ""):gsub("^%s*(.-)%s*$", "%1")
		if weather == "" then weather = "N/A|N/A" end
		local cond_en, temp = weather:match("([^|]+)|([^|]+)")
		if not cond_en then cond_en = weather temp = "" end
		-- Trim agresivo: quitar todos los espacios extras
		cond_en = cond_en:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
		temp = temp:gsub("^%s+", ""):gsub("%s+$", "")
		-- Traducir condiciones al español (busqueda case-insensitive)
		local locale = require("Jiyu.locale")
		local tr = {
			["clear"] = "Despejado", ["sunny"] = "Soleado",
			["partly cloudy"] = "Parcialmente nublado", ["cloudy"] = "Nublado",
			["overcast"] = "Cubierto", ["mist"] = "Neblina", ["fog"] = "Niebla",
			["light rain"] = "Lluvia ligera", ["moderate rain"] = "Lluvia moderada",
			["heavy rain"] = "Lluvia fuerte", ["light drizzle"] = "Llovizna ligera",
			["drizzle"] = "Llovizna", ["thunderstorm"] = "Tormenta",
			["light snow"] = "Nieve ligera", ["snow"] = "Nieve", ["heavy snow"] = "Nieve fuerte",
			["light showers"] = "Chubascos ligeros", ["showers"] = "Chubascos",
			["patchy rain possible"] = "Lluvia dispersa", ["patchy snow possible"] = "Nieve dispersa",
			["patchy fog possible"] = "Niebla dispersa",
			["patchy light rain"] = "Lluvia ligera dispersa", ["patchy light snow"] = "Nieve ligera dispersa",
			["misty"] = "Neblina", ["haze"] = "Calima",
			["light rain shower"] = "Chubascos ligeros", ["rain shower"] = "Chubascos",
			["light snow shower"] = "Chubascos de nieve ligeros", ["snow shower"] = "Chubascos de nieve",
			["patchy light rain with thunder"] = "Tormenta dispersa",
			["patchy light snow with thunder"] = "Tormenta de nieve dispersa",
		}
		local cond_es = (locale.get_lang() == "es") and (tr[cond_en:lower()] or cond_en) or cond_en
		-- Mapear condicion a icono emoji
		local icon = "🌡"
		local c = cond_en:lower()
		if c:find("clear") or c:find("sunny") then icon = "☀"
		elseif c:find("partly") then icon = "⛅"
		elseif c:find("cloud") or c:find("overcast") then icon = "☁"
		elseif c:find("rain") or c:find("drizzle") or c:find("shower") then icon = "🌧"
		elseif c:find("thunder") or c:find("storm") then icon = "⛈"
		elseif c:find("snow") then icon = "❄"
		elseif c:find("fog") or c:find("mist") then icon = "🌫"
		end
		weather_text:set_markup("<span color='" .. (beautiful.color and beautiful.color.text or "#000000") .. "'>" .. icon .. " " .. escape_markup(city) .. " · " .. escape_markup(cond_es) .. " " .. escape_markup(temp) .. "</span>")
	end

	-- Sanitizar nombre de ciudad para URL/shell: solo alfanuméricos, espacios y guiones
	local function sanitize_city(c)
		return (c:gsub("[^%w%s-]", ""))
	end

	-- Obtener ciudad: manual o por IP
	local function fetch_weather()
		if WEATHER_CITY ~= "" then
			awful.spawn.easy_async("curl -s 'https://wttr.in/" .. sanitize_city(WEATHER_CITY) .. "?format=%C|%t' 2>/dev/null", function(wout)
				update_weather_text(WEATHER_CITY, wout)
			end)
		else
			awful.spawn.easy_async("curl -s 'https://ipinfo.io/city' 2>/dev/null", function(stdout)
				local city = stdout:gsub("\n", ""):gsub("^%s*(.-)%s*$", "%1")
				if city == "" then city = "Madrid" end
				awful.spawn.easy_async("curl -s 'https://wttr.in/" .. sanitize_city(city) .. "?format=%C|%t' 2>/dev/null", function(wout)
					update_weather_text(city, wout)
				end)
			end)
		end
	end

	fetch_weather()
	-- Crear area compatible con desktop.build.static
	weather_w.body = { area = wibox.container.margin(weather_text, 10, 10, 10, 10) }
	weather_w.body.style = { color = { wibox = beautiful.desktopbg or "#d0d0d0" } }

	net_up.body = redflat.desktop.multiline(net_up.args, net_up.style)
	net_down.body = redflat.desktop.multiline(net_down.args, net_down.style)

	cpuwidget.body = redflat.desktop.multimeter(cpuwidget.args, cpuwidget.style)
	ramw.body = redflat.desktop.multiline(ramw.args, ramw.style)
	swapw.body = redflat.desktop.multiline(swapw.args, swapw.style)

	disk_root.body = redflat.desktop.multiline(disk_root.args, disk_root.style)
	disk_home.body = redflat.desktop.multiline(disk_home.args, disk_home.style)

	thermal_disk.body = redflat.desktop.multiline(thermal_disk.args, thermal_disk.style)

	-- Popup de sensores al hacer clic en el widget de temperatura del escritorio
	thermal_disk.body.area:buttons(awful.util.table.join(
		awful.button({}, 1, function() redflat.float.sensors:show() end),
		awful.button({}, 3, function() redflat.float.sensors:show() end)
	))

	fan.body = redflat.desktop.multiline(fan.args, fan.style)
	vnstat_d.body = redflat.desktop.multiline(vnstat_d.args, vnstat_d.style)
	vnstat_m.body = redflat.desktop.multiline(vnstat_m.args, vnstat_m.style)
	calendar.body = redflat.desktop.calendar(calendar.args, calendar.style)

	-- Desktop setup
	--------------------------------------------------------------------------------
	local desktop_objects = {
		calendar,
		net_up, net_down, cpuwidget, ramw, swapw,
		disk_root, disk_home, thermal_disk, fan,
		vnstat_d, vnstat_m,
		playerbar_w,
		weather_w,
	}

	if not autohide then
		redflat.util.desktop.build.static(desktop_objects, args.buttons)
	else
		redflat.util.desktop.build.dynamic(desktop_objects, nil, beautiful.desktopbg, args.buttons)
	end

	calendar.body:activate_wibox(calendar.wibox)

end

-- End
-----------------------------------------------------------------------------------------------------------------------
return desktop
