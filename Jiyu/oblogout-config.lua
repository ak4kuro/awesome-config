-----------------------------------------------------------------------------------------------------------------------
-- Menú compacto tipo oblogout (iconos + etiquetas). Orden y comandos editables aquí.                                 --
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local L = require("Jiyu.locale").t

local oblogout = require("redflat.float.oblogout")

local M = {}

function M:init()
	oblogout:set_entries({
		{ cancel = true, label = L("Cancel") },
		{
			icon_name = "lock",
			label     = L("Lock"),
			callback  = function()
				awful.spawn.with_shell("loginctl lock-session 2>/dev/null || xscreensaver-command -l")
			end,
		},
		{
			icon_name = "logout",
			label     = L("Log out"),
			callback  = function()
				awesome.quit()
			end,
		},
		{
			icon_name = "suspend",
			label     = L("Suspend"),
			callback  = function()
				awful.spawn.with_shell("systemctl suspend")
			end,
		},
		{
			icon_name = "reboot",
			label     = L("Reboot"),
			callback  = function()
				awful.spawn.with_shell("systemctl reboot")
			end,
		},
		{
			icon_name = "poweroff",
			label     = L("Shutdown"),
			callback  = function()
				awful.spawn.with_shell("systemctl poweroff")
			end,
		},
	})
end

return M
