-----------------------------------------------------------------------------------------------------------------------
--                                                  Language switcher                                                  --
-----------------------------------------------------------------------------------------------------------------------
-- Cambia entre español e inglés modificando rc.lua y reiniciando AwesomeWM
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local L = require("Jiyu.locale").t

local lang_switcher = {}

local rc_path = awful.util.get_configuration_dir() .. "rc.lua"

function lang_switcher.toggle()
	local f = io.open(rc_path, "r")
	if not f then
		naughty.notify({ title = L("Error"), text = L("Could not read rc.lua"), timeout = 5 })
		return
	end
	local content = f:read("*a")
	f:close()

	local current = content:match('local UI_LANG%s*=%s*"([^"]*)"')
	local new_value
	if current == "es" then
		new_value = "en"
	else
		new_value = "es"
	end

	local new_content = content:gsub(
		'local UI_LANG%s*=%s*"[^"]*"',
		'local UI_LANG = "' .. new_value .. '"'
	)

	f = io.open(rc_path, "w")
	if not f then
		naughty.notify({ title = L("Error"), text = L("Could not write rc.lua"), timeout = 5 })
		return
	end
	f:write(new_content)
	f:close()

	local lang_name = (new_value == "es") and L("Spanish") or L("English")
	naughty.notify({
		title = L("Language changed"),
		text = L("Restarting to") .. " " .. lang_name .. "...",
		timeout = 2,
	})

	gears.timer({
		timeout = 0.5,
		single_shot = true,
		callback = function()
			awesome.restart()
		end,
	}):start()
end

return lang_switcher
