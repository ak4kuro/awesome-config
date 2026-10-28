-----------------------------------------------------------------------------------------------------------------------
--                                           Active screen edges config                                              --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local redflat = require("redflat")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local edges = {}

local switcher = redflat.float.appswitcher
local currenttags = redflat.widget.tasklist.filter.currenttags
local allscreen   = redflat.widget.tasklist.filter.allscreen

-- Active screen edges (una instancia por pantalla)
-----------------------------------------------------------------------------------------------------------------------
function edges:init(args)

	args = args or {}
	local ew = args.width or 1 -- edge width
	local tcn = args.tag_cols_num or 0

	for s in screen do
		local workarea = s.workarea
		if workarea and workarea.width > 0 and workarea.height > 0 then
			self:_init_screen(s, workarea, ew, tcn)
		end
	end
end

function edges:_init_screen(s, workarea, ew, tcn)

	-- edge geometry (relativa a la pantalla)
	local sx, sy = workarea.x, workarea.y
	local egeometry = {
		top   = { width = workarea.width - 2 * ew, height = ew , x = sx + ew, y = sy },
		right = { width = ew, height = workarea.height, x = sx + workarea.width - ew, y = sy },
		left  = { width = ew, height = workarea.height, x = sx, y = sy },
	}

	-- Top
	--------------------------------------------------------------------------------
	local top = redflat.util.desktop.edge("horizontal")
	top.wibox:geometry(egeometry["top"])

	top.layout:buttons(awful.util.table.join(
		awful.button({}, 1,
			function()
				if client.focus then client.focus.maximized = not client.focus.maximized end
			end
		)
	))

	-- Right
	--------------------------------------------------------------------------------
	local right = redflat.util.desktop.edge("vertical", { ew, workarea.height - ew })
	right.wibox:geometry(egeometry["right"])

	right.area[1]:buttons(awful.util.table.join(
		awful.button({}, 5, function() awful.tag.viewnext(s) end),
		awful.button({}, 4, function() awful.tag.viewprev(s) end)
	))

	right.area[2]:buttons(awful.util.table.join(
		awful.button({}, 5, function() awful.tag.viewnext(s) end),
		awful.button({}, 4, function() awful.tag.viewprev(s) end)
	))

	-- Left
	--------------------------------------------------------------------------------
	local left = redflat.util.desktop.edge("vertical", { ew, workarea.height - ew })
	left.wibox:geometry(egeometry["left"])

	left.area[1]:buttons(awful.util.table.join(
		awful.button({}, 4, function() switcher:show({ filter = allscreen })                 end),
		awful.button({}, 5, function() switcher:show({ filter = allscreen, reverse = true }) end)
	))

	left.area[2]:buttons(awful.util.table.join(
		awful.button({}, 9, function() if client.focus then client.focus.minimized = true end  end),
		awful.button({}, 4, function() switcher:show({ filter = currenttags })                 end),
		awful.button({}, 5, function() switcher:show({ filter = currenttags, reverse = true }) end)
	))

	left.wibox:connect_signal("mouse::leave", function() redflat.float.appswitcher:hide() end)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return edges
