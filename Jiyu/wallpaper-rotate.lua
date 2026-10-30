-----------------------------------------------------------------------------------------------------------------------
--                                          Wallpaper rotation (toggle)                                              --
-----------------------------------------------------------------------------------------------------------------------
-- Rota el fondo de escritorio cada `interval` segundos entre las imágenes encontradas
-- en DIRS (más el directorio del tema). Mod4+w activa/desactiva; al desactivar se
-- restaura el wallpaper del tema vía env.wallpaper.
-----------------------------------------------------------------------------------------------------------------------

local gears = require("gears")
local naughty = require("naughty")
local beautiful = require("beautiful")

local M = { active = false, current = nil, interval = 300 }

local files, index, timer = {}, 0, nil

-- Directorios a escanear (se ignoran los que no existan)
local DIRS = {
	os.getenv("HOME") .. "/Imágenes",
	os.getenv("HOME") .. "/Pictures",
	"/usr/share/backgrounds",
}

local function scan()
	files = {}
	local dirs = {}
	if beautiful.path then table.insert(dirs, beautiful.path) end
	for _, d in ipairs(DIRS) do table.insert(dirs, d) end
	local f = io.popen(
		'find "' .. table.concat(dirs, '" "') .. '" -maxdepth 3 -type f'
		.. [[ \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) 2>/dev/null]]
	)
	if f then
		for line in f:lines() do table.insert(files, line) end
		f:close()
	end
end

local function apply(path)
	M.current = path
	for s in screen do
		gears.wallpaper.maximized(path, s, false)
	end
end

local function next_wall()
	if #files == 0 then return end
	index = (index % #files) + 1
	apply(files[index])
end

function M.toggle()
	if M.active then
		M.active = false
		M.current = nil
		if timer then timer:stop() end
		local ok, env = pcall(require, "Jiyu.env-config")
		if ok and env.wallpaper then
			for s in screen do env.wallpaper(s) end
		end
		naughty.notify({ title = "Wallpaper", text = "Rotación desactivada", timeout = 2 })
		return
	end

	scan()
	if #files == 0 then
		naughty.notify({ title = "Wallpaper", text = "No hay imágenes en las rutas configuradas", timeout = 3 })
		return
	end
	M.active = true
	index = 0
	next_wall()
	if not timer then
		timer = gears.timer({ timeout = M.interval, autostart = false, callback = next_wall })
	end
	timer:start()
	naughty.notify({ title = "Wallpaper", text = "Rotación activada (" .. #files .. " imágenes)", timeout = 2 })
end

return M
