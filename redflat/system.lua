-----------------------------------------------------------------------------------------------------------------------
--                                                   RedFlat system                                                  --
-----------------------------------------------------------------------------------------------------------------------
-- System monitoring functions collected here
-----------------------------------------------------------------------------------------------------------------------
-- Some code was taken from
------ vicious module
------ (c) 2010, 2011 Adrian C. <anrxc@sysphere.org>
------ (c) 2009, Lucas de Vries <lucas@glacicle.com>
------ (c) 2011, Jörg T. <jthalheim@gmail.com>
------ (c) 2011, Adrian C. <anrxc@sysphere.org>
-----------------------------------------------------------------------------------------------------------------------


-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local tonumber = tonumber
local io = io
local os = os
local string = string
local math = math

local timer = require("gears.timer")
local awful = require("awful")
local redutil = require("redflat.util")
local tr = require("redflat.util.lang").t

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local system = { thermal = {}, dformatted = {}, pformatted = {} }

-- Async settlers generator
-----------------------------------------------------------------------------------------------------------------------
function system.simple_async(command, pattern)
	return function(setup)
		awful.spawn.easy_async_with_shell(command,
			function(output)
				local value = tonumber(string.match(output, pattern))
				setup(value and { value } or { 0 })
			end
		)
	end
end

-- Temperatura vía smartctl -A (discos ATA/SATA). Varios formatos de salida; 194/190 SMART.
-- Hace falta poder leer el disco (p. ej. usuario en grupo «disk», reglas udev de smartmontools).
-----------------------------------------------------------------------------------------------------------------------
function system.smartctl_ata_temp(device)
	device = device or "/dev/sda"
	local cmd = "smartctl -A " .. device .. " 2>/dev/null"
	return function(setup)
		awful.spawn.easy_async_with_shell(cmd, function(output)
			local t = tonumber(string.match(output, "194%s+[%w_]+%s+0x%x+%s+(%d+)"))
			if not t then
				t = tonumber(string.match(output, "190%s+[%w_]+%s+0x%x+%s+(%d+)"))
			end
			if not t then
				t = tonumber(string.match(output, "194%s+[%w_]+%s+[^%c]+%s+(%d+)"))
			end
			if not t then
				local line = string.match(output, "194[^\n]+")
				if line then
					t = tonumber(string.match(line, "(%d+)%s*$"))
				end
			end
			setup(t and { t } or { 0 })
		end)
	end
end

-- Disk usage
-----------------------------------------------------------------------------------------------------------------------
function system.fs_info(args)
	local fs_info = {}
	args = args or "/"

	-- Get data from df
	------------------------------------------------------------
	local line = redutil.read.output("LC_ALL=C df -kP " .. args .. " | tail -1")

	-- Parse data
	------------------------------------------------------------
	fs_info.size  = string.match(line, "^.-[%s]([%d]+)")
	fs_info.mount = string.match(line, "%%[%s]([%p%w]+)")
	fs_info.used, fs_info.avail, fs_info.use_p = string.match(line, "([%d]+)[%D]+([%d]+)[%D]+([%d]+)%%")

	-- Format output special for redflat desktop widget
	------------------------------------------------------------
   return { tonumber(fs_info.use_p) or 0, tonumber(fs_info.used) or 0}
end

-- Uso de partición para escritorio: barra = %, texto = "usado/totalGB"
-----------------------------------------------------------------------------------------------------------------------
function system.desktop_fs_usage(mount)
	mount = mount or "/"
	local line = redutil.read.output("LC_ALL=C df -kP " .. mount .. " 2>/dev/null | tail -1")
	if not line or line == "" or line:match("^Filesystem") then
		return { 0, 0, text = "—" }
	end
	local blocks, used, _, pct = string.match(line, "^%S+%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%%")
	blocks = tonumber(blocks)
	used = tonumber(used)
	pct = tonumber(pct)
	if not blocks or not used then
		return { 0, 0, text = "—" }
	end
	if not pct then
		pct = math.floor(used / math.max(blocks, 1) * 100 + 0.5)
	end
	-- df -kP devuelve KiB; para GB reales hay que dividir entre 1024^2.
	local g_used = used / (1024 * 1024)
	local g_tot = blocks / (1024 * 1024)

	-- Texto compacto (sin porcentaje) para que quede más legible.
	-- Ej: "123.4/512GB"
	local text = string.format("%.1f/%.1fGB", g_used, g_tot)
	return { pct, used, text = text }
end

-- Primer disco con temperatura SMART legible (NVMe o SATA); prueba nvme0n1, sda, sdb
-----------------------------------------------------------------------------------------------------------------------
function system.disk_temp_auto(setup)
	-- 0) Intentar primero por hwmon/drivetemp (no requiere smartctl ni root).
	for i = 0, 31 do
		local base = "/sys/class/hwmon/hwmon" .. i
		local nf = io.open(base .. "/name", "r")
		if nf then
			local nm = nf:read("*l")
			nf:close()
			if nm and (nm == "drivetemp" or nm:match("nvme")) then
				for _, label in ipairs({ "temp1_input", "temp2_input", "temp3_input", "temp4_input" }) do
					local tf = io.open(base .. "/" .. label, "r")
					if tf then
						local raw = tonumber(tf:read("*l"))
						tf:close()
						if raw and raw > 0 then
							local c = math.floor(raw / 1000)
							setup({ math.min(c, 100), text = string.format("%d°C (hwmon)", c) })
							return
						end
					end
				end
			end
		end
	end

	local devs = {}
	for _, d in ipairs({ "/dev/nvme0n1", "/dev/nvme0n2", "/dev/sda", "/dev/sdb" }) do
		local f = io.open(d, "rb")
		if f then
			f:close()
			table.insert(devs, d)
		end
	end
	local idx = 1
	local function try_next()
		if idx > #devs then
			setup({ 0, text = "—" })
			return
		end
		local dev = devs[idx]
		idx = idx + 1
		local cmd = "smartctl -A " .. dev .. " 2>/dev/null"
		awful.spawn.easy_async_with_shell(cmd, function(output)
			local out = output or ""
			local t
			if dev:match("nvme") then
				t = tonumber(string.match(out, "Temperature:%s+(%d+)"))
				if not t then
					t = tonumber(string.match(out, "Temperature:%s+(%d+)%sCelsius"))
				end
			end
			if not t then
				t = tonumber(string.match(out, "194%s+[%w_]+%s+0x%x+%s+(%d+)"))
			end
			if not t then
				t = tonumber(string.match(out, "190%s+[%w_]+%s+0x%x+%s+(%d+)"))
			end
			if not t then
				local line194 = string.match(out, "194[^\n]+")
				if line194 then
					t = tonumber(string.match(line194, "(%d+)%s*$"))
				end
			end
			if t and t > 0 then
				setup({ math.min(t, 100), text = string.format("%d°C (%s)", t, dev) })
			else
				try_next()
			end
		end)
	end
	try_next()
end

-- Qemu image check
-----------------------------------------------------------------------------------------------------------------------
local function q_format(size, k)
	if not size or not k then return 0 end
	return k == "K" and tonumber(size) or k == "M" and size * 1024 or k == "G" and size * 1024^2 or 0
end

function system.qemu_image_size(args)
	local img_info = {}

	-- Get data from qemu-ima
	------------------------------------------------------------
	local line = redutil.read.output("LC_ALL=C qemu-img info " .. args)

	-- Parse data
	------------------------------------------------------------
	local size, k = string.match(line, "disk%ssize:%s([%.%d]+)%s(%w)")
	img_info.size = q_format(size, k)
	local vsize, vk = string.match(line, "virtual%ssize:%s([%.%d]+)%s(%w)")
	img_info.virtual_size = q_format(vsize, vk)
	img_info.use_p = img_info.virtual_size > 0 and math.floor(img_info.size / img_info.virtual_size * 100) or 0

	-- Format output special for redflat desktop widget
	------------------------------------------------------------
   return { img_info.use_p, img_info.size, off = img_info.size == 0 }
end

-- Traffic check with vnstat (async)
-- vnStat 2.x cambió el texto de -d/-m; el parseo antiguo (tabla con "|") dejaba RX en 0.
-- --oneline b: 15 campos con ';' (man vnstat); campo 4 = RX hoy, 9 = RX mes actual.
-----------------------------------------------------------------------------------------------------------------------
local vnstat_pattern = "%s+(%d+,%d+)%s(%w+)%s+%|%s+(%d+,%d+)%s(%w+)%s+%|%s+(%d+,%d+)%s(%w+)%s+%|%s+.+"
local vnstat_index = { rx = 1, tx = 3, total = 5 }

local function vnstat_format(value, unit)
	if not value or not unit then return 0 end
	local v = value:gsub(',', '.')
	return    unit == "B"   and tonumber(v)
	       or unit == "KiB" and v * 1024
	       or unit == "MiB" and v * 1024^2
	       or unit == "GiB" and v * 1024^3
end

local function vnstat_parse_legacy_pipe(output, traffic)
	local text = output or ""
	local index = vnstat_index[traffic]

	-- Busca la primera fila de datos real (no cabecera, no separador, no "estimated").
	for line in string.gmatch(text, "[^\r\n]+") do
		local low = string.lower(line)
		if line:find("|", 1, true)
			and not low:find("estimated", 1, true)
			and not low:find("rx", 1, true)
			and not line:match("^%s*%-+") then
			local statistic = { string.match(line, vnstat_pattern) }
			local x, u = statistic[index], statistic[index + 1]
			local value = vnstat_format(x, u)
			if value then
				return value
			end
		end
	end
	return 0
end

local function vnstat_split_semicolon(line)
	local parts = {}
	local start = 1
	local s = line or ""
	while true do
		local i, j = string.find(s, ";", start, true)
		if not i then
			table.insert(parts, string.sub(s, start))
			break
		end
		table.insert(parts, string.sub(s, start, i - 1))
		start = j + 1
	end
	return parts
end

local function vnstat_from_oneline(output, options, traffic)
	local line = string.match(output or "", "^([^\r\n]+)")
	if not line then
		return nil
	end
	local parts = vnstat_split_semicolon(line)
	-- Campo 1 = versión API oneline; con salida de error no hay 9 campos
	if #parts < 9 or not string.match(parts[1] or "", "^%d") then
		return nil
	end
	-- Campos oneline b:
	-- daily:   rx=4 tx=5 total=6
	-- monthly: rx=9 tx=10 total=11
	local base = (options == "-m") and 9 or 4
	local shift = (traffic == "tx") and 1 or (traffic == "total") and 2 or 0
	local idx = base + shift
	return tonumber(parts[idx]) or 0
end

function system.vnstat_check(args)
	args = type(args) == "table" and args or {} -- backward capability
	args.options = args.options or "-d"
	args.traffic = args.traffic or "total"

	local iface = args.interface
	local argv = { "vnstat" }
	if iface and iface ~= "" and iface ~= "auto" then
		table.insert(argv, "-i")
		table.insert(argv, iface)
	end
	table.insert(argv, "--oneline")
	table.insert(argv, "b")

	return function(setup)
		awful.spawn.easy_async(argv, function(output)
			local value = vnstat_from_oneline(output, args.options, args.traffic)
			if value ~= nil then
				setup({ value })
				return
			end
			local iface_args = (iface and iface ~= "" and iface ~= "auto") and ("-i " .. iface .. " ") or ""
			local command = string.format("vnstat %s%s 2>/dev/null", iface_args, args.options)
			awful.spawn.easy_async_with_shell(command, function(out2)
				setup({ vnstat_parse_legacy_pipe(out2, args.traffic) })
			end)
		end)
	end
end

-- Default IPv4 route interface (Ethernet vs Wi‑Fi according to active route)
-----------------------------------------------------------------------------------------------------------------------
function system.default_net_interface()
	local p = io.popen("ip -4 route show default 2>/dev/null")
	if p then
		for line in p:lines() do
			local dev = line:match("dev%s+(%S+)")
			if dev and dev ~= "lo" then
				p:close()
				return dev
			end
		end
		p:close()
	end
	local rf = io.open("/proc/net/route", "r")
	if rf then
		for line in rf:lines() do
			if not line:match("^Iface") and not line:match("^Kernel") then
				local iface, dest = string.match(line, "^(%S+)%s+(%S+)")
				if dest == "00000000" and iface and iface ~= "lo" then
					rf:close()
					return iface
				end
			end
		end
		rf:close()
	end
	return "eth0"
end

-- Get network speed
-----------------------------------------------------------------------------------------------------------------------
function system.net_speed(interface, storage)
	local up, down = 0, 0

	-- Get network info
	--------------------------------------------------------------------------------
	for line in io.lines("/proc/net/dev") do

		-- Nombre de interfaz antes de ':' (wlp60s0, enp0s3, br-xxx, veth123@eth0, etc.)
		local name = string.match(line, "^%s*(%S+):")
		if name and name:find("@", 1, true) then
			name = string.match(name, "^([^@]+)@")
		end

		-- Calculate speed for given interface
		------------------------------------------------------------
		if name == interface then
			-- Tras "iface:" hay 16 números típicos: RX bytes = [1], TX bytes = [9]
			local rest = line:match(":%s*(.+)$")
			local recv, send
			if rest then
				local nums = {}
				for n in rest:gmatch("%d+") do
					table.insert(nums, tonumber(n))
				end
				recv = nums[1]
				send = nums[9]
			end

			if recv and send then
				local now = os.time()

				if not storage[interface] then
					storage[interface] = { recv = 0, send = 0 }
				else
					local interval = now - storage[interface].time
					if interval <= 0 then interval = 1 end

					down = (recv - storage[interface].recv) / interval
					up   = (send - storage[interface].send) / interval
				end

				storage[interface].time = now
				storage[interface].recv = recv
				storage[interface].send = send
			end
		end
	end

	--------------------------------------------------------------------------------
	return { up, down }
end

-- Get disk speed
-----------------------------------------------------------------------------------------------------------------------
function system.disk_speed(disk, storage)
	local up, down = 0, 0

	-- Get i/o info
	--------------------------------------------------------------------------------
	for line in io.lines("/proc/diskstats") do

		-- parse info
		-- linux kernel documentation: Documentation/iostats.txt
		local device, read, write = string.match(line, "([^%s]+) %d+ %d+ (%d+) %d+ %d+ %d+ (%d+)")

		-- Calculate i/o for given device
		------------------------------------------------------------
		if device == disk then
			local now   = os.time()
			local stats = { read, write }

			if not storage[disk] then
				-- default values on the first run
				storage[disk] = { stats = stats }
			else
				-- check for overflows and counter resets (> 2^32)
				if stats[1] < storage[disk].stats[1] or stats[2] < storage[disk].stats[2] then
					storage[disk].stats[1], storage[disk].stats[2] = stats[1], stats[2]
				end

				-- diskstats are absolute, substract our last reading
				-- * divide by timediff because we don't know the timer value
				local interval = now - storage[disk].time
				if interval <= 0 then interval = 1 end

				up   = (stats[1] - storage[disk].stats[1]) / interval
				down = (stats[2] - storage[disk].stats[2]) / interval
			end

			-- store totals
			storage[disk].time = now
			storage[disk].stats = stats
		end
	end

	--------------------------------------------------------------------------------
	return { up, down }
end

-- Get MEM info
-----------------------------------------------------------------------------------------------------------------------
function system.memory_info()
	local mem = { buf = {}, swp = {} }

	-- Get MEM info
	------------------------------------------------------------
	for line in io.lines("/proc/meminfo") do
		for k, v in string.gmatch(line, "([%a]+):[%s]+([%d]+).+") do
			if     k == "MemTotal"  then mem.total = math.floor(v/1024)
			elseif k == "MemFree"   then mem.buf.f = math.floor(v/1024)
			elseif k == "Buffers"   then mem.buf.b = math.floor(v/1024)
			elseif k == "Cached"    then mem.buf.c = math.floor(v/1024)
			elseif k == "SwapTotal" then mem.swp.t = math.floor(v/1024)
			elseif k == "SwapFree"  then mem.swp.f = math.floor(v/1024)
			end
		end
	end

	-- Calculate memory percentage
	------------------------------------------------------------
	mem.free  = mem.buf.f + mem.buf.b + mem.buf.c
	mem.inuse = mem.total - mem.free
	mem.bcuse = mem.total - mem.buf.f
	mem.usep  = math.floor(mem.inuse / mem.total * 100)

	-- calculate swap percentage
	mem.swp.inuse = mem.swp.t - mem.swp.f
	mem.swp.usep  = mem.swp.t > 0 and math.floor(mem.swp.inuse / mem.swp.t * 100) or 0

	------------------------------------------------------------
	return mem
end

-- Get cpu usage info
-----------------------------------------------------------------------------------------------------------------------
--local storage = { cpu_total = {}, cpu_active = {} } -- storage structure

function system.cpu_usage(storage)
	local cpu_lines = {}
	local cpu_usage = {}
	local diff_time_total

	-- Get CPU stats
	------------------------------------------------------------
	for line in io.lines("/proc/stat") do
		if string.sub(line, 1, 3) == "cpu" then
			local digits_in_line = {}

			for i in string.gmatch(line, "[%s]+([^%s]+)") do
				table.insert(digits_in_line, i)
			end

			table.insert(cpu_lines, digits_in_line)
		end
	end

	-- Calculate usage
	------------------------------------------------------------
	for i, line in ipairs(cpu_lines) do

		-- calculate totals
		local total_new = 0
		for _, value in ipairs(line) do total_new = total_new + value end

		local active_new = total_new - (line[4] + line[5])

		-- calculate percentage
		local diff_total  = total_new  - (storage.cpu_total[i]  or 0)
		local diff_active = active_new - (storage.cpu_active[i] or 0)

		if i == 1 then diff_time_total = diff_total end
		if diff_total == 0 then diff_total = 1E-6 end

		cpu_usage[i] = math.floor((diff_active / diff_total) * 100)

		-- store totals
		storage.cpu_total[i]  = total_new
		storage.cpu_active[i] = active_new
	end

	-- Format output special for redflat widgets and other system functions
	------------------------------------------------------------
	local total_usage = cpu_usage[1]
	local core_usage = awful.util.table.clone(cpu_usage)
	table.remove(core_usage, 1)

	return { total = total_usage, core = core_usage, diff = diff_time_total }
end

-- Número de CPUs lógicas (líneas cpu0, cpu1, … en /proc/stat)
-----------------------------------------------------------------------------------------------------------------------
function system.cpu_core_count()
	local n = 0
	local f = io.open("/proc/stat", "r")
	if not f then
		return 1
	end
	for line in f:lines() do
		if line:match("^cpu%d+") then
			n = n + 1
		end
	end
	f:close()
	return math.max(1, n)
end

local function format_mem_used_total_mb(used, total, pct)
	if not total or total <= 0 then
		return "—"
	end
	if total >= 1024 then
		return string.format("%.1f / %.1f GB · %d%%", used / 1024, total / 1024, pct)
	end
	return string.format("%d / %d MB · %d%%", used, total, pct)
end

-- Get battery level and charging status
-----------------------------------------------------------------------------------------------------------------------
function system.battery(batname)
	if not batname then return end

	-- Initialzie vars
	--------------------------------------------------------------------------------
	local battery = {}
	local time = "N/A"

	local battery_state = {
		["Full\n"]        = "↯",
		["Unknown\n"]     = "⌁",
		["Charged\n"]     = "↯",
		["Charging\n"]    = "+",
		["Discharging\n"] = "-"
	}

	local files = {
		"present", "status", "charge_now",
		"charge_full", "energy_now", "energy_full",
		"current_now", "power_now"
	}

	-- Read info
	--------------------------------------------------------------------------------
	for _, v in pairs(files) do
		battery[v] = redutil.read.file("/sys/class/power_supply/" .. batname .. "/" .. v)
	end

	-- Check if the battery is present
	------------------------------------------------------------
	if battery.present ~= "1\n" then
		return { battery_state["Unknown\n"], 0, "N/A" }
	end

	-- Get state information
	------------------------------------------------------------
	local state = battery_state[battery.status] or battery_state["Unknown\n"]
	local remaining, capacity

	-- Get capacity information
	if     battery.charge_now then remaining, capacity = battery.charge_now, battery.charge_full
	elseif battery.energy_now then remaining, capacity = battery.energy_now, battery.energy_full
	else                           return {battery_state["Unknown\n"], 0, "N/A"}
	end

	-- Calculate percentage (but work around broken BAT/ACPI implementations)
	------------------------------------------------------------
	local percent = math.min(math.floor(remaining / capacity * 100), 100)

	-- Get charge information
	------------------------------------------------------------
	local rate

	if     battery.current_now then rate = tonumber(battery.current_now)
	elseif battery.power_now   then rate = tonumber(battery.power_now)
	else                            return {state, percent, "N/A"}
	end

	-- Calculate remaining (charging or discharging) time
	------------------------------------------------------------
	if rate ~= nil and rate ~= 0 then
		local timeleft

		if     state == "+" then timeleft = (tonumber(capacity) - tonumber(remaining)) / tonumber(rate)
		elseif state == "-" then timeleft = tonumber(remaining) / tonumber(rate)
		else                     return {state, percent, time}
		end

		-- calculate time
		local hoursleft   = math.floor(timeleft)
		local minutesleft = math.floor((timeleft - hoursleft) * 60 )

		time = string.format("%02d:%02d", hoursleft, minutesleft)
	end

	--------------------------------------------------------------------------------
	return { state, percent, time }
end

-- Primer suministro BAT* en sysfs (portátil)
-----------------------------------------------------------------------------------------------------------------------
function system.default_battery_supply()
	local p = io.popen("ls /sys/class/power_supply 2>/dev/null")
	if not p then
		return nil
	end
	local found
	for name in p:lines() do
		if name:match("^BAT") then
			found = name
			break
		end
	end
	p:close()
	return found
end

-- Formato multilínea del escritorio: { nivel, nivel, text = "…" }
-----------------------------------------------------------------------------------------------------------------------
function system.desktop_battery_usage()
	local bat = system.default_battery_supply()
	if not bat then
		return { 0, 0, text = tr("AC power") }
	end
	local st = system.battery(bat)
	if not st then
		return { 0, 0, text = tr("—") }
	end
	local state, pct, time = st[1], st[2], st[3]
	-- Tooltip desktop battery: prefijo BAT solicitado.
	local text = string.format("BAT %s %d%% %s", state, pct, time)
	return { pct, pct, text = text }
end

-- Temperature measure
-----------------------------------------------------------------------------------------------------------------------

-- Using lm-sensors
------------------------------------------------------------
system.lmsensors = { storage = {}, patterns = {}, delay = 1, time = 0, last_sensors_output = "" }

function system.lmsensors:update(output)
	self.last_sensors_output = output
	for name, pat in pairs(self.patterns) do
		local value
		if type(pat.match) == "table" then
			for _, p in ipairs(pat.match) do
				value = string.match(output, p)
				if value then
					break
				end
			end
		else
			value = string.match(output, pat.match)
		end
		if value and pat.posthook then value = pat.posthook(value) end
		value = tonumber(value)
		self.storage[name] = value and { value } or { 0 }
	end
	self.time = os.time()
end

function system.lmsensors:start(timeout)
	if self.timer then return end

	self.timer = timer({ timeout = timeout })
	self.timer:connect_signal("timeout", function()
		awful.spawn.easy_async("sensors", function(output) system.lmsensors:update(output) end)
	end)

	self.timer:start()
	self.timer:emit_signal("timeout")
end

function system.lmsensors:soft_start(timeout, shift)
	if self.timer then return end

	timer({
		timeout     = timeout - (shift or 1),
		autostart   = true,
		single_shot = true,
		callback    = function() self:start(timeout) end
	})
end

function system.lmsensors.get(name)
	if os.time() - system.lmsensors.time > system.lmsensors.delay then
		local output = redutil.read.output("sensors")
		system.lmsensors:update(output)
	end
	return system.lmsensors.storage[name] or { 0 }
end

-- Temperatura Wi‑Fi (iwlwifi): thermal_zone, hwmon, luego salida de `sensors` (patrones flexibles).
-----------------------------------------------------------------------------------------------------------------------
local function wifi_temp_from_sensors_text(text)
	if not text or text == "" then
		return nil
	end
	local patterns = {
		-- Bloque típico (sin depender del símbolo ° por codificación UTF-8)
		"iwlwifi[^\n]+\nAdapter:[^\n]+\n%s*temp1:%s+%+(%d+)%.?%d*",
		"iwlwifi[^\n]+\n[^\n]+\n%s*temp1:%s+%+(%d+)%.?%d*",
		"iwlwifi_1%-virtual%-0\r?\nAdapter:%sVirtual%sdevice\r?\ntemp1:%s+%+(%d+)%.?%d*",
	}
	for _, p in ipairs(patterns) do
		local v = tonumber(string.match(text, p))
		if v then
			return { v }
		end
	end
	return nil
end

function system.wifi_temp_get()
	-- 1) thermal_zone* cuyo type menciona iwlwifi (algunos kernels solo exponen aquí)
	local p = io.popen("ls -d /sys/class/thermal/thermal_zone* 2>/dev/null")
	if p then
		for path in p:lines() do
			local typ = redutil.read.file(path .. "/type")
			if typ and typ:match("iwlwifi") then
				local raw = redutil.read.file(path .. "/temp")
				if raw then
					local millideg = tonumber((raw:gsub("%s+", "")))
					if millideg then
						p:close()
						return { math.floor(millideg / 1000) }
					end
				end
			end
		end
		p:close()
	end

	-- 2) hwmon: nombre iwlwifi_0000, iwlwifi_1, etc. (no solo ^iwlwifi)
	for i = 0, 31 do
		local base = "/sys/class/hwmon/hwmon" .. i
		local nf = io.open(base .. "/name", "r")
		if nf then
			local nm = nf:read("*l")
			nf:close()
			if nm and nm:match("iwlwifi") then
				local tf = io.open(base .. "/temp1_input", "r")
				if tf then
					local millideg = tonumber(tf:read("*l"))
					tf:close()
					if millideg then
						return { math.floor(millideg / 1000) }
					end
				end
			end
		else
			break
		end
	end

	-- 3) lm-sensors: misma salida que usa el resto de sensores + regex de respaldo
	if os.time() - system.lmsensors.time > system.lmsensors.delay
		or not system.lmsensors.last_sensors_output
		or system.lmsensors.last_sensors_output == "" then
		local output = redutil.read.output("sensors")
		system.lmsensors:update(output)
	end

	local alt = wifi_temp_from_sensors_text(system.lmsensors.last_sensors_output or "")
	if alt then
		return alt
	end

	return system.lmsensors.storage.wifi or { 0 }
end

-- Legacy
------------------------------------------------------------
--function system.thermal.sensors(args)
--	local args = args or "'Physical id 0'"
--	local output = redutil.read.output("sensors | grep " .. args)
--
--	local temp = string.match(output, "%+(%d+%.%d)°[CF]")
--
--	return temp and { math.floor(tonumber(temp)) } or { 0 }
--end
--
--local sensors_store
--
--function system.thermal.sensors_core(args)
--	args = args or {}
--	local index = args.index or 0
--
--	if args.main then sensors_store = redutil.read.output("sensors | grep Core") end
--	local line = string.match(sensors_store, "Core " .. index .."(.-)\r?\n")
--
--	if not line then return { 0 } end
--
--	local temp = string.match(line, "%+(%d+%.%d)°[CF]")
--	return temp and { math.floor(tonumber(temp)) } or { 0 }
--end

-- Using hddtemp
------------------------------------------------------------
function system.thermal.hddtemp(args)
	args = args or {}
	local port = args.port or "7634"
	local disk = args.disk or "/dev/sda"

	local output = redutil.read.output("echo | curl --connect-timeout 1 -fsm 3 telnet://127.0.0.1:" .. port)

	for mnt, _, temp, _ in output:gmatch("|(.-)|(.-)|(.-)|(.-)|") do
		if mnt == disk then
			return temp and { tonumber(temp) }
		end
	end

	return { 0 }
end

-- Using nvidia-settings on sysmem with optimus (bumblebee)
-- Async
------------------------------------------------------------
function system.thermal.nvoptimus(setup)
	local nvidia_on = string.find(redutil.read.output("cat /proc/acpi/bbswitch"), "ON")
	if not nvidia_on then
		setup({ 0, off = true })
	else
		awful.spawn.easy_async_with_shell("optirun -b none nvidia-settings -c :8 -q gpucoretemp -t | tail -1",
			function(output)
				local value = tonumber(string.match(output, "[^\n]+"))
				setup({ value or 0, off = false })
			end
		)
	end
end

-- Direct call of nvidia-smi
------------------------------------------------------------
function system.thermal.nvsmi()
	local temp = string.match(
		redutil.read.output("nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader"), "%d%d"
	)
	-- checks that local temp is not null then returns the convert string to number or if fails returns null
	return temp and { tonumber(temp) } or { 0 }
end

-- Using nvidia-smi on sysmem with optimus (nvidia-prime)
------------------------------------------------------------
function system.thermal.nvprime()
	local temp = 0
	local nvidia_on = string.find(redutil.read.output("prime-select query"), "nvidia")

	if nvidia_on ~= nil then
		-- reuse function nvsmi
		temp = system.thermal.nvsmi()[1]
	end

	return { temp, off = nvidia_on == nil }
end

-- GPU (NVIDIA / AMD / Intel i915) para widget de escritorio — sync, valores en °C
-----------------------------------------------------------------------------------------------------------------------
function system.thermal.gpu_temp_desktop()
	local nv = system.thermal.nvsmi()
	if nv[1] and tonumber(nv[1]) and nv[1] > 0 then
		local c = nv[1]
		return { c, c, text = string.format("GPU %d°C", c) }
	end
	local pr = system.thermal.nvprime()
	if pr and not pr.off and pr[1] and tonumber(pr[1]) and pr[1] > 0 then
		local c = pr[1]
		return { c, c, text = string.format("GPU %d°C", c) }
	end
	for i = 0, 15 do
		local base = "/sys/class/hwmon/hwmon" .. i
		local nf = io.open(base .. "/name", "r")
		if nf then
			local nm = nf:read("*l")
			nf:close()
			if nm == "amdgpu" then
				local tf = io.open(base .. "/temp1_input", "r")
				if tf then
					local raw = tonumber(tf:read("*l"))
					tf:close()
					if raw and raw > 0 then
						local c = math.floor(raw / 1000)
						return { c, c, text = string.format("GPU %d°C", c) }
					end
				end
			end
		end
	end
	for i = 0, 15 do
		local base = "/sys/class/hwmon/hwmon" .. i
		local nf = io.open(base .. "/name", "r")
		if nf then
			local nm = nf:read("*l")
			nf:close()
			if nm == "i915" then
				for _, lab in ipairs({ "temp1_input", "temp2_input" }) do
					local tf = io.open(base .. "/" .. lab, "r")
					if tf then
						local raw = tonumber(tf:read("*l"))
						tf:close()
						if raw and raw > 0 then
							local c = math.floor(raw / 1000)
							if c > 0 and c < 120 then
								return { c, c, text = string.format(tr("GPU %d°C"), c) }
							end
						end
					end
				end
			end
		end
	end
	return { 0, 0, text = tr("GPU —") }
end

-- Get info from transmission-remote client
-- This function adapted special for async reading
-----------------------------------------------------------------------------------------------------------------------
system.transmission = {}

-- Check if transmission client running
--------------------------------------------------------------------------------
function system.transmission.is_running(args)
	local t_client = args or "transmission-gtk"
	return redutil.read.output("pidof -x " .. t_client) ~= ""
end

-- Function for torrents sorting (downloading and paused first)
--------------------------------------------------------------------------------
function system.transmission.sort_torrent(a, b)
	return a.status == "Downloading" and b.status ~= "Downloading"
	       or a.status == "Stopped" and b.status ~= "Stopped" and b.status ~= "Downloading"
end

-- Function to parse 'transmission-remote -l' output
--------------------------------------------------------------------------------
function system.transmission.parse(output, show_active_only)

	-- Initialize vars
	------------------------------------------------------------
	local torrent = {
		seed = { num = 0, speed = 0 },
		dnld = { num = 0, speed = 0 },
		list = {},
	}

	-- Find state and progress for every torrent
	-- and total upload and downoad speed
	------------------------------------------------------------
	--local status_pos = string.find(output, "Status")

	-- assuming "Up & Down" and "Downloading" is the same thing
	output = string.gsub(output, "Up & Down", "Downloading")

	-- parse every line
	for line in string.gmatch(output, "[^\r\n]+") do

		if string.sub(line, 1, 3) == "Sum" then
			-- get total speed
			local seed, dnld = string.match(line, "Sum:%s+[%d%.]+%s+%a+%s+([%d%.]+)%s+([%d%.]+)")
			seed, dnld = tonumber(seed), tonumber(dnld)
			if seed and dnld then
				torrent.seed.speed, torrent.dnld.speed = seed, dnld
			end
		else
			-- get torrent info
			local prog, status, name = string.match(
				line,
				"%s+%d+%s+(%d+)%%%s+[%d%.]+%s%a+%s+.+%s+[%d%.]+%s+[%d%.]+%s+[%d%.]+%s+(%a+)%s+(.+)"
			)

			if prog and status then
				-- if active only is selected then filter
				if not show_active_only or (status == "Downloading" or status == "Seeding") then
					table.insert(torrent.list, { prog = prog, status = status, name = name })
				end

				if status == "Seeding" then
					torrent.seed.num = torrent.seed.num + 1
				elseif status == "Downloading" then
					torrent.dnld.num = torrent.dnld.num + 1
				end
			end
		end
	end

	-- Sort torrents
	------------------------------------------------------------
	-- do not need to sort active as transmission-remote automatically sorts
	if not show_active_only then
		table.sort(torrent.list, system.transmission.sort_torrent)
	end

	-- Format output special for redflat desktop widget
	------------------------------------------------------------
	local sorted_prog = {}
	for _, t in ipairs(torrent.list) do
		table.insert(sorted_prog, { value = t.prog, text = string.format("%d%% %s", t.prog, t.name) })
	end

	return {
		bars = sorted_prog,
		lines = { { torrent.seed.speed, torrent.seed.num }, { torrent.dnld.speed, torrent.dnld.num } },
		alert = false
	}
end

-- Async transmission meter function
--------------------------------------------------------------------------------
function system.transmission.info(setup, args)
	local command = args.command or "transmission-remote localhost -l"

	awful.spawn.easy_async(command, function(output)
		-- rather than check if an instance of transmission is running locally, check if there is actually any output
		-- zero torrents or no program equates to same result
		if string.len(output) > 0 then
			local state = system.transmission.parse(output, args.show_active_only)

			if args.speed_only then
				state.lines[1][2] = state.lines[1][1]
				state.lines[2][2] = state.lines[2][1]
			end
			setup(state)
		else
			setup({ bars = {}, lines = { { 0, 0 }, { 0, 0 } }, alert = true })
		end
	end)
end

-- Get processes list and cpu and memory usage for every process
-- !!! Fixes is needed !!!
-----------------------------------------------------------------------------------------------------------------------
local proc_storage = {}

function system.proc_info(cpu_storage)
	local process = {}
	local mem_page_size = 4

	-- get processes list with ps utility
	-- !!! TODO: get processes list from fs directly !!!
	local output = redutil.read.output("ps -eo pid | tail -n +2")

	-- get total cpu time diff from previous call
	local cpu_diff = system.cpu_usage(cpu_storage).diff

	-- handle every line in ps output
	for line in string.gmatch(output, "[^\n]+") do
		local pid = tonumber(line)

		-- try to get info from /proc
		local stat = redutil.read.file("/proc/" .. pid .. "/stat")

		-- if process with given pid exist in /proc
		if stat then

			-- get process name
			local name = string.match(stat, ".+%((.+)%).+")
			local proc_stat = { name }

			-- remove process name from stat data to simplify following parsing
			stat = stat:gsub("%s%(.+%)", "", 1)

			-- the rest of 'stat' data can be splitted by whitespaces
			-- first chunk is pid so just skip it
			for m in string.gmatch(stat, "[%s]+([^%s]+)") do
				table.insert(proc_stat, m)
			end

			-- get memory usage (RSS)
			-- !!! RSS is a very crude approximation for memory usage !!!
			-- !!! TODO: find a more accurate method for real memory usage calculation !!!
			local mem = proc_stat[23] * mem_page_size

			-- calculate cpu usage for process
			local proc_time = proc_stat[13] + proc_stat[14]
			local pcpu = (proc_time - (proc_storage[pid] or 0)) / cpu_diff

			-- save current cpu time for future
			proc_storage[pid] = proc_time

			-- save results
			table.insert(process, { pid = pid, name = name, mem = mem, pcpu = pcpu })
		end
	end

	return process
end

-- Output format functions
-----------------------------------------------------------------------------------------------------------------------

-- CPU and memory usage formatted special for desktop widget
--------------------------------------------------------------------------------
function system.dformatted.cpumem(storage)
	local mem = system.memory_info()
	local cores = {}
	for i, v in ipairs(system.cpu_usage(storage).core) do
		table.insert(cores, { value = v, text = string.format("CORE%d %s%%", i - 1, v) })
	end

	local ram_txt = format_mem_used_total_mb(mem.inuse, mem.total, mem.usep)
	local swp_total = mem.swp.t or 0
	local swp_line
	if swp_total <= 0 then
		swp_line = { 0, 0, text = tr("No swap") }
	else
		swp_line = {
			mem.swp.usep,
			mem.swp.inuse,
			text = format_mem_used_total_mb(mem.swp.inuse, swp_total, mem.swp.usep),
		}
	end

	return {
		bars = cores,
		lines = {
			{ mem.usep, mem.inuse, text = ram_txt },
			swp_line,
		},
	}
end

-- Solo núcleos CPU (escritorio: widget separado de RAM/swap)
--------------------------------------------------------------------------------
function system.dformatted.cpu_only(storage)
	local cores = {}
	for i, v in ipairs(system.cpu_usage(storage).core) do
		table.insert(cores, { value = v, text = string.format("CORE%d %s%%", i - 1, v) })
	end
	return { bars = cores, lines = {} }
end

-- RAM / swap para widget multilínea del escritorio (valores en MB como memory_info)
--------------------------------------------------------------------------------
function system.desktop_ram_usage()
	local mem = system.memory_info()
	return {
		mem.usep,
		mem.inuse,
		text = format_mem_used_total_mb(mem.inuse, mem.total, mem.usep),
	}
end

function system.desktop_swap_usage()
	local mem = system.memory_info()
	local swp_total = mem.swp.t or 0
	if swp_total <= 0 then
		return { 0, 0, text = tr("No swap") }
	end
	return {
		mem.swp.usep,
		mem.swp.inuse,
		text = format_mem_used_total_mb(mem.swp.inuse, swp_total, mem.swp.usep),
	}
end

-- CPU usage formatted special for panel widget
--------------------------------------------------------------------------------
function system.pformatted.cpu(crit)
	crit = crit or 75
	local storage = { cpu_total = {}, cpu_active = {} }

	return function()
		local usage = system.cpu_usage(storage).total
		return {
			value = usage / 100,
			text  = usage .. "%",
			alert = usage > crit
		}
	end
end

-- Memory usage formatted special for panel widget
--------------------------------------------------------------------------------
function system.pformatted.mem(crit)
	crit = crit or 75

	return function()
		local usage = system.memory_info().usep
		return {
			value = usage / 100,
			text  = usage .. "%",
			alert = usage > crit
		}
	end
end

-- Battery state formatted special for panel widget
--------------------------------------------------------------------------------
function system.pformatted.bat(crit)
	crit = crit or 15

	return function(arg)
		local state = system.battery(arg)
		return {
			value = state[2] / 100,
			text  = state[1] .. "  " .. state[2] .. "%  " .. state[3],
			alert = state[2] < crit
		}
	end
end

-- Temperature formatted special for panel widget (circle gauge + tooltip)
--------------------------------------------------------------------------------
function system.pformatted.temp(crit)
	crit = crit or 75

	return function()
		local v = system.lmsensors.get("cpu")
		local temp = v[1] or 0
		return {
			value = temp / 100,
			text  = temp .. "°C",
			alert = temp > crit
		}
	end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return system
