-----------------------------------------------------------------------------------------------------------------------
--  Ayudantes para tags: evita awful.tag.viewtoggle(nil) y callbacks con argumentos erróneos del ratón.              --
-----------------------------------------------------------------------------------------------------------------------
local awful = require("awful")

local M = {}

function M.viewtoggle(t)
	if t == nil then
		return
	end
	pcall(awful.tag.viewtoggle, t)
end

function M.view_only(t)
	if t == nil then
		return
	end
	pcall(function()
		t:view_only()
	end)
end

function M.viewnext_from_tag(t)
	if t == nil or t.screen == nil then
		return
	end
	awful.tag.viewnext(t.screen)
end

function M.viewprev_from_tag(t)
	if t == nil or t.screen == nil then
		return
	end
	awful.tag.viewprev(t.screen)
end

return M
