-----------------------------------------------------------------------------------------------------------------------
--                                          Hotkeys and mouse buttons config                                         --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local table = table
local unpack = unpack or table.unpack
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local redflat = require("redflat")
local L = require("Jiyu.locale").t
local tagutil = require("Jiyu.util-tag")
local dock = require("Jiyu.dock")
local clipboard = require("Jiyu.clipboard")
local theme_switcher = require("Jiyu.theme-switcher")
local lang_switcher = require("Jiyu.lang-switcher")
local periodic_popup = require("Jiyu.periodic-popup")
local wallrotate = require("Jiyu.wallpaper-rotate")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local hotkeys = { mouse = {}, raw = {}, keys = {}, fake = {} }

-- key aliases
local apprunner = redflat.float.apprunner
local appswitcher = redflat.float.appswitcher
local current = redflat.widget.tasklist.filter.currenttags
local allscr = redflat.widget.tasklist.filter.allscreen
local laybox = redflat.widget.layoutbox
local redtip = redflat.float.hotkeys
local laycom = redflat.layout.common
local grid = redflat.layout.grid
local map = redflat.layout.map
local logout = redflat.service.logout
local qlaunch = redflat.float.qlaunch
local numkeys_line = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

-- Key support functions
-----------------------------------------------------------------------------------------------------------------------

-- change window focus by direction
local focus_switch_byd = function(dir)
	return function()
		awful.client.focus.bydirection(dir)
		if client.focus then client.focus:raise() end
	end
end

-- minimize and restore windows (pantalla = focused, no mouse.screen deprecado)
local function minimize_all()
	local scr = awful.screen.focused()
	if not scr then return end
	for _, c in ipairs(client.get()) do
		if current(c, scr) then c.minimized = true end
	end
end

local function minimize_all_except_focused()
	local scr = awful.screen.focused()
	if not scr then return end
	for _, c in ipairs(client.get()) do
		if current(c, scr) and c ~= client.focus then c.minimized = true end
	end
end

local function restore_all()
	local scr = awful.screen.focused()
	if not scr then return end
	for _, c in ipairs(client.get()) do
		if current(c, scr) and c.minimized then c.minimized = false end
	end
end

local function restore_client()
	local c = awful.client.restore()
	if c then client.focus = c; c:raise() end
end

-- close window
local function kill_all()
	local scr = awful.screen.focused()
	if not scr then return end
	for _, c in ipairs(client.get()) do
		if current(c, scr) and not c.sticky then c:kill() end
	end
end

-- window properties
local function client_property(p)
	if client.focus then client.focus[p] = not client.focus[p] end
end

-- new clients placement
local function toggle_placement(env)
	env.set_slave = not env.set_slave
	redflat.float.notify:show({ text = (env.set_slave and L("Slave") or L("Master")) .. " " .. L("placement") })
end

-- ir al tag i de la pantalla con foco
local function tag_select(i)
	local screen = awful.screen.focused()
	if not screen then return end
	local tag = screen.tags[i]
	if tag then tag:view_only() end
end

local function current_clients()
	return awful.screen.focused().selected_tag:clients()
end

local function client_move_by_index(i, group)
	for _, c in ipairs(group) do
		c:move_to_tag(awful.screen.focused().tags[i])
	end
end

local function client_move_and_go_by_index(i, group)
	local tag = awful.screen.focused().tags[i]
	for _, c in ipairs(group) do c:move_to_tag(tag) end
	tag:view_only()
end

local function client_toggle_by_index(i, group)
	for _, c in ipairs(group) do
		c:toggle_tag(awful.screen.focused().tags[i])
	end
end

-- Multimonitor: mover la ventana enfocada a la pantalla siguiente/anterior (circular)
local function move_client_to_screen(c, dir)
	if not c or not c.screen then return end
	local screens = {}
	for s in screen do table.insert(screens, s) end
	if #screens < 2 then return end
	local idx = nil
	for i, s in ipairs(screens) do
		if s == c.screen then idx = i; break end
	end
	if not idx then return end
	local next_idx = ((idx + dir - 1) % #screens) + 1
	c:move_to_screen(screens[next_idx])
	-- llevar el foco a la nueva pantalla para que la ventana no quede "perdida"
	awful.screen.focus_relative(dir)
end

-- numeric keys function builders
local function tag_numkey(i, mod, action)
	return awful.key(
		mod, "#" .. i + 9,
		function ()
			local screen = awful.screen.focused()
			local tag = screen.tags[i]
			if tag then action(tag) end
		end
	)
end

-- brightness control integrado en Lua/shell (sin script externo python)
-- Fallback a xrandr cuando no hay backlight hardware (monitores externos)
local brightness_control = {
	increase = [[bash -lc 'step=%s; [ "$step" -lt 1 ] && step=1; ok=0; if command -v brightnessctl >/dev/null 2>&1 && brightnessctl -c backlight set "${step}%%+" >/dev/null 2>&1; then ok=1; fi; if [ "$ok" -ne 1 ]; then d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); pct=$(( (cur*100 + max/2) / max )); npct=$((pct + step)); [ "$npct" -gt 100 ] && npct=100; new=$(( (npct*max + 50) / 100 )); [ "$new" -gt "$max" ] && new=$max; echo "$new" > "$d/brightness" 2>/dev/null; echo $npct; exit 0; fi; fi; if [ "$ok" -ne 1 ]; then cur=$(xrandr --verbose 2>/dev/null | grep -m1 "Brightness:" | awk "{print \$2}"); cur=${cur:-1.0}; npct=$(awk "BEGIN{v=$cur+($step/100); if(v>1.0)v=1.0; printf \"%.2f\", v}"); for o in $(xrandr --query 2>/dev/null | grep " connected" | awk "{print \$1}"); do xrandr --output "$o" --brightness "$npct" 2>/dev/null; done; echo $(awk "BEGIN{printf \"%d\", $npct*100}"); exit 0; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); [ -z "$d" ] && echo 0 && exit 0; max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); echo $(( (cur*100 + max/2) / max ))']],
	decrease = [[bash -lc 'step=%s; [ "$step" -lt 1 ] && step=1; ok=0; if command -v brightnessctl >/dev/null 2>&1 && brightnessctl -c backlight set "${step}%%-" >/dev/null 2>&1; then ok=1; fi; if [ "$ok" -ne 1 ]; then d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); if [ -n "$d" ]; then max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); pct=$(( (cur*100 + max/2) / max )); npct=$((pct - step)); [ "$npct" -lt 0 ] && npct=0; new=$(( (npct*max + 50) / 100 )); [ "$new" -lt 0 ] && new=0; echo "$new" > "$d/brightness" 2>/dev/null; echo $npct; exit 0; fi; fi; if [ "$ok" -ne 1 ]; then cur=$(xrandr --verbose 2>/dev/null | grep -m1 "Brightness:" | awk "{print \$2}"); cur=${cur:-1.0}; npct=$(awk "BEGIN{v=$cur-($step/100); if(v<0.1)v=0.1; printf \"%.2f\", v}"); for o in $(xrandr --query 2>/dev/null | grep " connected" | awk "{print \$1}"); do xrandr --output "$o" --brightness "$npct" 2>/dev/null; done; echo $(awk "BEGIN{printf \"%d\", $npct*100}"); exit 0; fi; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); [ -z "$d" ] && echo 0 && exit 0; max=$(cat "$d/max_brightness"); cur=$(cat "$d/brightness"); echo $(( (cur*100 + max/2) / max ))']],
}

redflat.float.brightness.default_variant = brightness_control

local brightness = function(args)
	redflat.float.brightness:change(args)
end

-- Esquina inferior derecha del área útil, subida como theme.float.player.bottom_anchor_lift (reproductor flotante).
local rb_corner = function()
	local scr = awful.screen.focused()
	if not scr then return { x = 0, y = 0 } end
	local wa = scr.workarea
	local lift = 120
	if beautiful.float.player and beautiful.float.player.bottom_anchor_lift then
		lift = beautiful.float.player.bottom_anchor_lift
	end
	return { x = wa.x + wa.width, y = wa.y + wa.height - lift }
end

-- Tabla periódica de atajos: módulo Jiyu/periodic-popup.lua (popup con rejilla de grupos y detalle)

-- Build hotkeys depended on config parameters
-----------------------------------------------------------------------------------------------------------------------
function hotkeys:init(args)

	-- Init vars
	args = args or {}
	local env = args.env
	local mainmenu = args.menu
	local volume = args.volume
	local microphone = args.microphone
	local appkeys = args.appkeys or {}
	local show_hotkeys_on_startup = args.show_hotkeys_on_startup == true

	local tcn = args.tag_cols_num or 0

	local numkeys = { unpack(numkeys_line, 1, tcn) }
	local project_hotkeys_pack = {}

	self.mouse.root = (awful.util.table.join(
		awful.button({ }, 3, function () mainmenu:toggle() end),
		awful.button({ }, 4, awful.tag.viewnext),
		awful.button({ }, 5, awful.tag.viewprev)
	))

	-- volume functions
	local volume_raise = function() volume:change_volume({ show_notify = true }) end
	local volume_lower = function() volume:change_volume({ show_notify = true, down = true }) end
	local volume_mute  = function() volume:mute() end

	-- Init widgets
	redflat.float.qlaunch:init()

	-- Application hotkeys helper
	--------------------------------------------------------------------------------
	local apphelper = function(keys)
		if not client.focus then return end

		local app = client.focus.class:lower()
		for name, sheet in pairs(keys) do
			if name == app then
				redtip:set_pack(
						client.focus.class, sheet.pack, sheet.style.column, sheet.style.geometry,
						function() redtip:remove_pack() end
				)
				redtip:show()
				return
			end
		end

		redflat.float.notify:show({ text = L("No tips for") .. " " .. client.focus.class })
	end

	-- Keys for widgets
	--------------------------------------------------------------------------------

	-- Apprunner widget
	------------------------------------------------------------
	local apprunner_keys_move = {
		{
			{ env.mod }, "k", function() apprunner:down() end,
			{ description = L("Select next item"), group = L("Navigation")}
		},
		{
			{ env.mod }, "i", function() apprunner:up() end,
			{ description = L("Select previous item"), group = L("Navigation")}
		},
	}

	 apprunner:set_keys(awful.util.table.join(apprunner.keys.move, apprunner_keys_move), "move")
	--apprunner:set_keys(apprunner_keys_move, "move")

	-- Log out screen
	------------------------------------------------------------
	local logout_extra_keys = {
		{
			{}, "j", logout.action.select_prev,
			{ description = L("Select previous option"), group = L("Selection")}
		},
		{
			{}, "l", logout.action.select_next,
			{ description = L("Select next option"), group = L("Selection")}
		},
	}

	logout:set_keys(awful.util.table.join(logout.keys, logout_extra_keys))

	-- Menu widget
	------------------------------------------------------------
	local menu_keys_move = {
		{
			{ env.mod }, "k", redflat.menu.action.down,
			{ description = L("Select next item"), group = L("Navigation")}
		},
		{
			{ env.mod }, "i", redflat.menu.action.up,
			{ description = L("Select previous item"), group = L("Navigation")}
		},
		{
			{ env.mod }, "j", redflat.menu.action.back,
			{ description = L("Go back"), group = L("Navigation")}
		},
		{
			{ env.mod }, "l", redflat.menu.action.enter,
			{ description = L("Open submenu"), group = L("Navigation")}
		},
	}

	redflat.menu:set_keys(awful.util.table.join(redflat.menu.keys.move, menu_keys_move), "move")
	--redflat.menu:set_keys(menu_keys_move, "move")

	-- Updates widget
	------------------------------------------------------------
	local updates_keys_action = {
		{
			{ env.mod }, ",", function() redflat.widget.updates:hide() end,
			{ description = L("Close updates widget"), group = L("Action")}
		},
	}

	-- close widget by the same key as showing
	redflat.widget.updates:set_keys(
		awful.util.table.join(redflat.widget.updates.keys.action, updates_keys_action), "action"
	)

	-- Top process list
	------------------------------------------------------------
	local top_keys_action = {
		{
			{ env.mod }, "/", function() redflat.float.top:hide() end,
			{ description = L("Close top list widget"), group = L("Action")}
		},
	}

	-- close widget by the same key as showing
	redflat.float.top:set_keys(
		awful.util.table.join(redflat.float.top.keys.action, top_keys_action), "action"
	)

	-- Appswitcher widget
	------------------------------------------------------------
	local appswitcher_keys = {
		{
			{ env.mod }, "a", function() appswitcher:switch() end,
			{ description = L("Select next app"), group = L("Navigation")}
		},
		{
			{ env.mod, "Shift" }, "a", function() appswitcher:switch() end,
			{} -- hidden key
		},
		{
			{}, "Super_L", function() appswitcher:hide() end,
			{ description = L("Activate and exit"), group = L("Action")}
		},
		{
			{ env.mod }, "Super_L", function() appswitcher:hide() end,
			{} -- hidden key
		},
		{
			{ env.mod, "Shift" }, "Super_L", function() appswitcher:hide() end,
			{} -- hidden key
		},
		{
			{}, "Return", function() appswitcher:hide() end,
			{ description = L("Activate and exit"), group = L("Action")}
		},
		{
			{}, "Escape", function() appswitcher:hide(true) end,
			{ description = L("Exit"), group = L("Action")}
		},
		{
			{ env.mod }, "Escape", function() appswitcher:hide(true) end,
			{} -- hidden key
		},
		{
			{ env.mod }, "F1", function() redtip:show()  end,
			{ description = L("Show hotkeys helper"), group = L("Action")}
		},
	}

	appswitcher:set_keys(appswitcher_keys)

	-- Emacs like key sequences
	--------------------------------------------------------------------------------

	-- initial key
	local keyseq = { { env.mod }, "c", {}, {} }

	-- group
	keyseq[3] = {
		{ {}, "a", {}, {} }, -- wm management
		{ {}, "k", {}, {} }, -- application kill
		{ {}, "r", {}, {} }, -- client restore
		{ {}, "n", {}, {} }, -- client minimization
		{ {}, "f", {}, {} }, -- client moving
		{ {}, "s", {}, {} }, -- client switching
		{ {}, "d", {}, {} }, -- client move and tag switch
		{ {}, "u", {}, {} }, -- update info
		{ {}, "p", {}, {} }, -- client properties

		{ { "Shift" }, "f", {}, {} }, -- clients moving group
		{ { "Shift" }, "s", {}, {} }, -- clients switching group
		{ { "Shift" }, "d", {}, {} }, -- clients move and tag switch group
	}

	-- wm management sequence actions
	keyseq[3][1][3] = {
		{
			{}, "p", function () toggle_placement(env) end,
			{ description = L("Switch master/slave window placement"), group = L("Awesome management"), keyset = { "p" } }
		},
		{
			{}, "r", function () awesome.restart() end,
			{ description = L("Reload awesome"), group = L("Awesome management"), keyset = { "r" } }
		},
	}

	-- application kill sequence actions
	keyseq[3][2][3] = {
		{
			{}, "f", function() if client.focus then client.focus:kill() end end,
			{ description = L("Kill focused client"), group = L("Kill application"), keyset = { "f" } }
		},
		{
			{}, "a", kill_all,
			{ description = L("Kill all clients with current tag"), group = L("Kill application"), keyset = { "a" } }
		},
	}

	-- application restore sequence actions
	keyseq[3][3][3] = {
		{
			{}, "f", restore_client,
			{ description = L("Restore minimized client"), group = L("Clients management"), keyset = { "f" } }
		},
		{
			{}, "a", restore_all,
			{ description = L("Restore all clients with current tag"), group = L("Clients management"), keyset = { "a" } }
		},
	}

	-- application minimize sequence actions
	keyseq[3][4][3] = {
		{
			{}, "f", function() if client.focus then client.focus.minimized = true end end,
			{ description = L("Minimized focused client"), group = L("Clients management"), keyset = { "f" } }
		},
		{
			{}, "a", minimize_all,
			{ description = L("Minimized all clients with current tag"), group = L("Clients management"), keyset = { "a" } }
		},
		{
			{}, "e", minimize_all_except_focused,
			{ description = L("Minimized all clients except focused"), group = L("Clients management"), keyset = { "e" } }
		},
	}

	-- add client tag sequence actions (without description)
	for i, k in ipairs(numkeys) do
		table.insert(keyseq[3][5][3], { {}, k, function() client_move_by_index(i, { client.focus })        end, {} })
		table.insert(keyseq[3][6][3], { {}, k, function() client_toggle_by_index(i, { client.focus })      end, {} })
		table.insert(keyseq[3][7][3], { {}, k, function() client_move_and_go_by_index(i, { client.focus }) end, {} })
	end

	-- make fake keys with description special for key helper widget
	local grp = L("Client tagging")
	local line1_symb = string.format("%s..%s", numkeys[1], numkeys[#numkeys])

	table.insert(keyseq[3][5][3], {
		{}, line1_symb, nil, { description = L("Move client to tag"), group = grp, keyset = numkeys }
	})
	table.insert(keyseq[3][6][3], {
		{}, line1_symb, nil, { description = L("Toggle client on tag"), group = grp, keyset = numkeys }
	})
	table.insert(keyseq[3][7][3], {
		{}, line1_symb, nil, { description = L("Move client and show tag"), group = grp, keyset = numkeys }
	})

	-- widget info update commands
	keyseq[3][8][3] = {
		{
			{}, "u", function() redflat.widget.updates:update(true) end,
			{ description = L("Check available updates"), group = L("Update info"), keyset = { "u" } }
		},
		{
			{}, "c", function() redflat.float.top_cpu:show() end,
			{ description = L("Top CPU processes"), group = L("Update info"), keyset = { "c" } }
		},
		{
			{}, "m", function() redflat.float.top_mem:show() end,
			{ description = L("Top memory processes"), group = L("Update info"), keyset = { "m" } }
		},
		{
			{}, "s", function() if env.run_speedtest then env.run_speedtest() end end,
			{ description = L("Network speed test"), group = L("Update info"), keyset = { "s" } }
		},
	}

	-- client properties switch
	keyseq[3][9][3] = {
		{
			{}, "s", function() client_property("sticky") end,
			{ description = L("Toggle sticky"), group = L("Client properties"), keyset = { "s" } }
		},
		{
			{}, "o", function() client_property("ontop") end,
			{ description = L("Toggle keep on top"), group = L("Client properties"), keyset = { "o" } }
		},
		{
			{}, "f", function() client_property("floating") end,
			{ description = L("Toggle floating"), group = L("Client properties"), keyset = { "f" } }
		},
		{
			{}, "b", function() client_property("below") end,
			{ description = L("Toggle below"), group = L("Client properties"), keyset = { "b" } }
		},
	}

	-- add groups of clients tag sequence actions (hidden keys)
	for i, k in ipairs(numkeys) do
		table.insert(keyseq[3][10][3], { {}, k, function() client_move_by_index(i, current_clients())        end, {} })
		table.insert(keyseq[3][11][3], { {}, k, function() client_toggle_by_index(i, current_clients())      end, {} })
		table.insert(keyseq[3][12][3], { {}, k, function() client_move_and_go_by_index(i, current_clients()) end, {} })
	end

	-- Layouts
	--------------------------------------------------------------------------------

	-- shared layout keys
	local layout_tile = {
		{
			{ env.mod }, "l", function () awful.tag.incmwfact( 0.05) end,
			{ description = L("Increase master width factor"), group = L("Layout")}
		},
		{
			{ env.mod }, "j", function () awful.tag.incmwfact(-0.05) end,
			{ description = L("Decrease master width factor"), group = L("Layout")}
		},
		{
			{ env.mod }, "i", function () awful.client.incwfact( 0.05) end,
			{ description = L("Increase window factor of a client"), group = L("Layout")}
		},
		{
			{ env.mod }, "k", function () awful.client.incwfact(-0.05) end,
			{ description = L("Decrease window factor of a client"), group = L("Layout")}
		},
		{
			{ env.mod, }, "+", function () awful.tag.incnmaster( 1, nil, true) end,
			{ description = L("Increase the number of master clients"), group = L("Layout")}
		},
		{
			{ env.mod }, "-", function () awful.tag.incnmaster(-1, nil, true) end,
			{ description = L("Decrease the number of master clients"), group = L("Layout")}
		},
		{
			{ env.mod, "Control" }, "+", function () awful.tag.incncol( 1, nil, true) end,
			{ description = L("Increase the number of columns"), group = L("Layout")}
		},
		{
			{ env.mod, "Control" }, "-", function () awful.tag.incncol(-1, nil, true) end,
			{ description = L("Decrease the number of columns"), group = L("Layout")}
		},
	}

	laycom:set_keys(layout_tile, "tile")

	-- grid layout keys
	local layout_grid_move = {
		{
			{ env.mod }, "KP_Up", function() grid.move_to("up") end,
			{ description = L("Move window up"), group = L("Movement")}
		},
		{
			{ env.mod }, "KP_Down", function() grid.move_to("down") end,
			{ description = L("Move window down"), group = L("Movement")}
		},
		{
			{ env.mod }, "KP_Left", function() grid.move_to("left") end,
			{ description = L("Move window left"), group = L("Movement")}
		},
		{
			{ env.mod }, "KP_right", function() grid.move_to("right") end,
			{ description = L("Move window right"), group = L("Movement")}
		},
		{
			{ env.mod, "Control" }, "KP_Up", function() grid.move_to("up", true) end,
			{ description = L("Move window up by bound"), group = L("Movement")}
		},
		{
			{ env.mod, "Control" }, "KP_Down", function() grid.move_to("down", true) end,
			{ description = L("Move window down by bound"), group = L("Movement")}
		},
		{
			{ env.mod, "Control" }, "KP_Left", function() grid.move_to("left", true) end,
			{ description = L("Move window left by bound"), group = L("Movement")}
		},
		{
			{ env.mod, "Control" }, "KP_Right", function() grid.move_to("right", true) end,
			{ description = L("Move window right by bound"), group = L("Movement")}
		},
	}

	local layout_grid_resize = {
		{
			{ env.mod }, "i", function() grid.resize_to("up") end,
			{ description = L("Inrease window size to the up"), group = L("Resize")}
		},
		{
			{ env.mod }, "k", function() grid.resize_to("down") end,
			{ description = L("Inrease window size to the down"), group = L("Resize")}
		},
		{
			{ env.mod }, "j", function() grid.resize_to("left") end,
			{ description = L("Inrease window size to the left"), group = L("Resize")}
		},
		{
			{ env.mod }, "l", function() grid.resize_to("right") end,
			{ description = L("Inrease window size to the right"), group = L("Resize")}
		},
		{
			{ env.mod, "Shift" }, "i", function() grid.resize_to("up", nil, true) end,
			{ description = L("Decrease window size from the up"), group = L("Resize")}
		},
		{
			{ env.mod, "Shift" }, "k", function() grid.resize_to("down", nil, true) end,
			{ description = L("Decrease window size from the down"), group = L("Resize")}
		},
		{
			{ env.mod, "Shift" }, "j", function() grid.resize_to("left", nil, true) end,
			{ description = L("Decrease window size from the left"), group = L("Resize")}
		},
		{
			{ env.mod, "Shift" }, "l", function() grid.resize_to("right", nil, true) end,
			{ description = L("Decrease window size from the right"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "i", function() grid.resize_to("up", true) end,
			{ description = L("Increase window size to the up by bound"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "k", function() grid.resize_to("down", true) end,
			{ description = L("Increase window size to the down by bound"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "j", function() grid.resize_to("left", true) end,
			{ description = L("Increase window size to the left by bound"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "l", function() grid.resize_to("right", true) end,
			{ description = L("Increase window size to the right by bound"), group = L("Resize")}
		},
		{
			{ env.mod, "Control", "Shift" }, "i", function() grid.resize_to("up", true, true) end,
			{ description = L("Decrease window size from the up by bound "), group = L("Resize")}
		},
		{
			{ env.mod, "Control", "Shift" }, "k", function() grid.resize_to("down", true, true) end,
			{ description = L("Decrease window size from the down by bound "), group = L("Resize")}
		},
		{
			{ env.mod, "Control", "Shift" }, "j", function() grid.resize_to("left", true, true) end,
			{ description = L("Decrease window size from the left by bound "), group = L("Resize")}
		},
		{
			{ env.mod, "Control", "Shift" }, "l", function() grid.resize_to("right", true, true) end,
			{ description = L("Decrease window size from the right by bound "), group = L("Resize")}
		},
	}

	redflat.layout.grid:set_keys(layout_grid_move, "move")
	redflat.layout.grid:set_keys(layout_grid_resize, "resize")

	-- user map layout keys
	local layout_map_layout = {
		{
			{ env.mod }, "s", function() map.swap_group() end,
			{ description = L("Change placement direction for group"), group = L("Layout")}
		},
		{
			{ env.mod }, "v", function() map.new_group(true) end,
			{ description = L("Create new vertical group"), group = L("Layout")}
		},
		{
			{ env.mod }, "h", function() map.new_group(false) end,
			{ description = L("Create new horizontal group"), group = L("Layout")}
		},
		{
			{ env.mod, "Control" }, "v", function() map.insert_group(true) end,
			{ description = L("Insert new vertical group before active"), group = L("Layout")}
		},
		{
			{ env.mod, "Control" }, "h", function() map.insert_group(false) end,
			{ description = L("Insert new horizontal group before active"), group = L("Layout")}
		},
		{
			{ env.mod }, "d", function() map.delete_group() end,
			{ description = L("Destroy group"), group = L("Layout")}
		},
		{
			{ env.mod, "Control" }, "d", function() map.clean_groups() end,
			{ description = L("Destroy all empty groups"), group = L("Layout")}
		},
		{
			{ env.mod }, "f", function() map.set_active() end,
			{ description = L("Set active group"), group = L("Layout")}
		},
		{
			{ env.mod }, "g", function() map.move_to_active() end,
			{ description = L("Move focused client to active group"), group = L("Layout")}
		},
		{
			{ env.mod, "Control" }, "f", function() map.hilight_active() end,
			{ description = L("Hilight active group"), group = L("Layout")}
		},
		{
			{ env.mod }, "a", function() map.switch_active(1) end,
			{ description = L("Activate next group"), group = L("Layout")}
		},
		{
			{ env.mod }, "q", function() map.switch_active(-1) end,
			{ description = L("Activate previous group"), group = L("Layout")}
		},
		{
			{ env.mod }, "]", function() map.move_group(1) end,
			{ description = L("Move active group to the top"), group = L("Layout")}
		},
		{
			{ env.mod }, "[", function() map.move_group(-1) end,
			{ description = L("Move active group to the bottom"), group = L("Layout")}
		},
		{
			{ env.mod }, "r", function() map.reset_tree() end,
			{ description = L("Reset layout structure"), group = L("Layout")}
		},
	}

	local layout_map_resize = {
		{
			{ env.mod }, "j", function() map.incfactor(nil, 0.1, false) end,
			{ description = L("Increase window horizontal size factor"), group = L("Resize")}
		},
		{
			{ env.mod }, "l", function() map.incfactor(nil, -0.1, false) end,
			{ description = L("Decrease window horizontal size factor"), group = L("Resize")}
		},
		{
			{ env.mod }, "i", function() map.incfactor(nil, 0.1, true) end,
			{ description = L("Increase window vertical size factor"), group = L("Resize")}
		},
		{
			{ env.mod }, "k", function() map.incfactor(nil, -0.1, true) end,
			{ description = L("Decrease window vertical size factor"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "j", function() map.incfactor(nil, 0.1, false, true) end,
			{ description = L("Increase group horizontal size factor"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "l", function() map.incfactor(nil, -0.1, false, true) end,
			{ description = L("Decrease group horizontal size factor"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "i", function() map.incfactor(nil, 0.1, true, true) end,
			{ description = L("Increase group vertical size factor"), group = L("Resize")}
		},
		{
			{ env.mod, "Control" }, "k", function() map.incfactor(nil, -0.1, true, true) end,
			{ description = L("Decrease group vertical size factor"), group = L("Resize")}
		},
	}

	redflat.layout.map:set_keys(layout_map_layout, "layout")
	redflat.layout.map:set_keys(layout_map_resize, "resize")


	-- Global keys
	--------------------------------------------------------------------------------
	self.raw.root = {
		{
			{ env.mod }, "F1", function() redtip:show() end,
			{ description = L("[Hold] Awesome hotkeys helper"), group = L("Help")}
		},
		{
			{ env.mod, "Control" }, "F1", function() apphelper(appkeys) end,
			{ description = L("[Hold] Hotkeys helper for application"), group = L("Help")}
		},
		{
			{ env.mod, "Shift" }, "F1", function() periodic_popup.show(project_hotkeys_pack) end,
			{ description = L("Show project hotkeys popup"), group = L("Help")}
		},

		{
			{ env.mod }, "F2", function () redflat.service.navigator:run() end,
			{ description = L("[Hold] Tiling window control mode"), group = L("Window control")}
		},
		{
			{ env.mod }, "b", function() redflat.float.bartip:show() end,
			{ description = L("[Hold] Titlebar control"), group = L("Window control")}
		},
		{
			{ env.mod }, "h", function() redflat.float.control:show() end,
			{ description = L("[Hold] Floating window control mode"), group = L("Window control")}
		},

		{
			{ env.mod }, "Return", function() awful.spawn(env.terminal) end,
			{ description = L("Open a terminal"), group = L("Applications")}
		},
		-- F12: toggle Guake (terminal desplegable)
		{
			{}, "F12", function() awful.spawn("guake --toggle-visibility", false) end,
			{ description = L("Toggle Guake terminal"), group = L("Applications")}
		},
		{
			{ env.mod, "Shift" }, "d", function() dock:toggle() end,
			{ description = L("Toggle dock"), group = L("Applications")}
		},
		{
			{ env.mod, "Mod1" }, "c", function() clipboard:toggle_popup() end,
			{ description = L("Clipboard history"), group = L("Applications")}
		},
		{
			{ env.mod, "Mod1" }, "t", function() theme_switcher.toggle() end,
			{ description = L("Toggle light/dark theme"), group = L("Applications")}
		},
		{
			{ env.mod, "Mod1" }, "l", function() lang_switcher.toggle() end,
			{ description = L("Toggle language (es/en)"), group = L("Applications")}
		},
		{
			{ env.mod, "Shift" }, "l", function()
				awful.spawn.with_shell("XSECURELOCK_AUTH=auth_x11 XSECURELOCK_AUTHPROTO=authproto_pam XSECURELOCK_SAVER=dimmer XSECURELOCK_DIM_TIME=2 XSECURELOCK_DIM_COLOR='#1a1a1a' xsecurelock")
			end,
			{ description = L("Lock screen"), group = L("Applications")}
		},
		{
			{ env.mod, "Mod1" }, "n", function()
				awful.spawn.easy_async_with_shell(
					'pgrep -x gammastep > /dev/null && (killall gammastep; echo "OFF") || (gammastep -O 4500 -b 1.0 > /dev/null 2>&1 & echo "ON")',
					function(out)
						local naughty = require("naughty")
						if out and out:match("ON") then
							naughty.notify({ title = L("Night light"), text = L("Enabled (4500K)"), timeout = 3 })
						else
							naughty.notify({ title = L("Night light"), text = L("Disabled"), timeout = 3 })
						end
					end
				)
			end,
			{ description = L("Toggle night light"), group = L("Applications")}
		},
		-- Capturas de pantalla con scrot
		{
			{}, "Print", function()
				local fname = os.date("~/Pictures/screenshots/%Y-%m-%d_%H%M%S_full.png")
				awful.spawn.with_shell("mkdir -p ~/Pictures/screenshots && scrot " .. fname)
				local naughty = require("naughty")
				naughty.notify({ title = L("Screenshot"), text = fname, timeout = 3 })
			end,
			{ description = L("Full screenshot"), group = L("Screenshots")}
		},
		{
			{ env.mod }, "Print", function()
				local fname = os.date("~/Pictures/screenshots/%Y-%m-%d_%H%M%S_window.png")
				awful.spawn.with_shell("mkdir -p ~/Pictures/screenshots && scrot -u " .. fname)
				local naughty = require("naughty")
				naughty.notify({ title = L("Screenshot"), text = fname, timeout = 3 })
			end,
			{ description = L("Window screenshot"), group = L("Screenshots")}
		},
		{
			{ "Shift" }, "Print", function()
				local fname = os.date("~/Pictures/screenshots/%Y-%m-%d_%H%M%S_region.png")
				local naughty = require("naughty")
				-- scrot -s bloquea hasta terminar/cancelar la selección: notificar solo si hay archivo.
				awful.spawn.easy_async_with_shell(
					"mkdir -p ~/Pictures/screenshots && scrot -s " .. fname,
					function(_, _, _, code)
						if code == 0 then
							naughty.notify({ title = L("Screenshot"), text = fname, timeout = 3 })
						end
					end
				)
			end,
			{ description = L("Region screenshot"), group = L("Screenshots")}
		},
		-- Historial de notificaciones (dunst)
		{
			{ env.mod, "Mod1" }, "h", function()
				awful.spawn.with_shell("dunstctl history-pop 2>/dev/null || true")
			end,
			{ description = L("Show notification history"), group = L("Applications")}
		},
		-- Cerrar todas las notificaciones
		{
			{ env.mod, "Shift" }, "h", function()
				awful.spawn.with_shell("dunstctl close-all 2>/dev/null || true")
			end,
			{ description = L("Close all notifications"), group = L("Applications")}
		},

		{
			{ env.mod }, "l", focus_switch_byd("right"),
			{ description = L("Go to right client"), group = L("Client focus")}
		},
		{
			{ env.mod }, "j", focus_switch_byd("left"),
			{ description = L("Go to left client"), group = L("Client focus")}
		},
		{
			{ env.mod }, "i", focus_switch_byd("up"),
			{ description = L("Go to upper client"), group = L("Client focus")}
		},
		{
			{ env.mod }, "k", focus_switch_byd("down"),
			{ description = L("Go to lower client"), group = L("Client focus")}
		},
		{
			{ env.mod }, "u", awful.client.urgent.jumpto,
			{ description = L("Go to urgent client"), group = L("Client focus")}
		},
		--{
		--	{ env.mod }, "z", focus_to_previous,
		--	{ description = L("Go to previos client"), group = L("Client focus")}
		--},

		{
			{ env.mod }, "/", function() redflat.float.top:show("cpu") end,
			{ description = L("Top process list"), group = L("Widgets")}
		},
		{
			{ env.mod }, ",", function() redflat.widget.updates:show() end,
			{ description = L("System updates info"), group = L("Widgets")}
		},
		{
			{ env.mod }, "`", function() redflat.widget.minitray:toggle() end,
			{ description = L("Minitray"), group = L("Widgets")}
		},
		{
			{ env.mod, "Control" }, "n", function() redflat.float.netctl:show() end,
			{ description = L("Red Wi-Fi / cable (nmcli)"), group = L("Widgets")}
		},
		{
			{ env.mod }, "c", function() redflat.float.keychain:activate(keyseq, L("User")) end,
			{ description = L("User key sequence"), group = L("Widgets")}
		},
		{
			{ env.mod }, "z", function() redflat.float.oblogout:show() end,
			{ description = L("Shutdown menu"), group = L("Widgets")}
		},
		{
			{ env.mod, "Shift" }, "x", function() redflat.float.oblogout:show() end,
			{ description = L("Shutdown menu"), group = L("Widgets")}
		},

		{
			{ env.mod }, "a", nil, function() appswitcher:show({ filter = current }) end,
			{ description = L("Switch to next with current tag"), group = L("Application switcher")}
		},
		{
			{ env.mod, "Shift" }, "a", nil, function() appswitcher:show({ filter = allscr }) end,
			{ description = L("Switch to next through all tags"), group = L("Application switcher")}
		},

		{
			{ env.mod }, "Tab", awful.tag.history.restore,
			{ description = L("Swith to previos tag by history"), group = L("Tag navigation")}
		},
		{
			{ env.mod }, "Right", awful.tag.viewnext,
			{ description = L("View next tag"), group = L("Tag navigation")}
		},
		{
			{ env.mod }, "Left", awful.tag.viewprev,
			{ description = L("View previous tag"), group = L("Tag navigation")}
		},

		-- Multimonitor: mover el foco entre pantallas
		{
			{ env.mod, "Control" }, "Right", function() awful.screen.focus_relative(1) end,
			{ description = L("Focus next screen"), group = L("Screen")}
		},
		{
			{ env.mod, "Control" }, "Left", function() awful.screen.focus_relative(-1) end,
			{ description = L("Focus previous screen"), group = L("Screen")}
		},
		{
			{ env.mod }, "w", function() wallrotate.toggle() end,
			{ description = L("Toggle wallpaper rotation"), group = L("Screen")}
		},

		{
			{ env.mod }, "s", function() mainmenu:show() end,
			{ description = L("Main menu"), group = L("Launchers")}
		},
		{
			{ env.mod }, "d", function() apprunner:show() end,
			{ description = L("Application launcher"), group = L("Launchers")}
		},
		{
			{ env.mod }, "p", function() redflat.float.prompt:run() end,
			{ description = L("Prompt box"), group = L("Launchers")}
		},
		{
			{ env.mod }, "g", function() qlaunch:show() end,
			{ description = L("Application quick launcher"), group = L("Launchers")}
		},

		{
			{}, "XF86AudioRaiseVolume", volume_raise,
			{ description = L("Increase volume"), group = L("Volume control")}
		},
		{
			{}, "XF86AudioLowerVolume", volume_lower,
			{ description = L("Reduce volume"), group = L("Volume control")}
		},
		{
			{}, "XF86AudioMute", volume_mute,
			{ description = L("Mute audio"), group = L("Volume control")}
		},
		{
			{ "Control" }, "XF86AudioMute", function () microphone:mute() end,
			{ description = L("Mute microphone"), group = L("Volume control")}
		},

		{
			{}, "XF86MonBrightnessUp", function() brightness({ step = 2 }) end,
			{ description = L("Increase brightness"), group = L("Brightness control")}
		},
		{
			{}, "XF86MonBrightnessDown", function() brightness({ step = 2, down = true }) end,
			{ description = L("Reduce brightness"), group = L("Brightness control")}
		},

		{
			{ env.mod }, ".", function() redflat.float.player:show(rb_corner()) end,
			{ description = L("Show/hide widget"), group = L("Audio player")}
		},
		{
			{}, "XF86AudioPlay", function() redflat.float.player:action("PlayPause") end,
			{ description = L("Play/Pause track"), group = L("Audio player")}
		},
		{
			{}, "XF86AudioNext", function() redflat.float.player:action("Next") end,
			{ description = L("Next track"), group = L("Audio player")}
		},
		{
			{}, "XF86AudioPrev", function() redflat.float.player:action("Previous") end,
			{ description = L("Previous track"), group = L("Audio player")}
		},

		{
			{ env.mod }, "v", function()
				local s = awful.screen.focused()
				if s and s.selected_tag then laybox:toggle_menu(s.selected_tag) end
			end,
			{ description = L("Show layout menu"), group = L("Layouts")}
		},
		{
			{ env.mod}, "]", function() awful.layout.inc(1) end,
			{ description = L("Select next layout"), group = L("Layouts")}
		},
		{
			{ env.mod }, "[", function() awful.layout.inc(-1) end,
			{ description = L("Select previous layout"), group = L("Layouts")}
		},

		--{
		--	{ env.mod, "Control" }, "s", function() for s in screen do env.wallpaper(s) end end,
		--	{} -- hidden key
		--}
	}

	-- Client keys
	--------------------------------------------------------------------------------
	self.raw.client = {
		{
			{ env.mod }, "f", function(c) c.fullscreen = not c.fullscreen; c:raise() end,
			{ description = L("Toggle fullscreen"), group = L("Client keys")}
		},
		{
			{ env.mod }, "F4", function(c) c:kill() end,
			{ description = L("Close"), group = L("Client keys")}
		},
		{
			{ env.mod }, "n", function(c) c.minimized = true end,
			{ description = L("Minimize"), group = L("Client keys")}
		},
		{
			{ env.mod }, "m", function(c) c.maximized = not c.maximized; c:raise() end,
			{ description = L("Maximize"), group = L("Client keys")}
		},
		-- Multimonitor: mover ventana a la pantalla siguiente/anterior
		{
			{ env.mod, "Shift" }, "Right", function(c) move_client_to_screen(c, 1) end,
			{ description = L("Move to next screen"), group = L("Screen")}
		},
		{
			{ env.mod, "Shift" }, "Left", function(c) move_client_to_screen(c, -1) end,
			{ description = L("Move to previous screen"), group = L("Screen")}
		}
	}

	self.keys.root = redflat.util.key.build(self.raw.root)
	self.keys.client = redflat.util.key.build(self.raw.client)

	-- Numkeys
	--------------------------------------------------------------------------------

	-- add real keys without description here
	for i = 1, tcn do
		self.keys.root = awful.util.table.join(
			self.keys.root,
			tag_numkey(i, { env.mod },            function(_) tag_select(i) end),
			tag_numkey(i, { env.mod, "Control" }, function(t) tagutil.viewtoggle(t) end),
			-- Atajos clásicos de awesome: mover/alternar la ventana enfocada en el tag i
			tag_numkey(i, { env.mod, "Shift" },   function(t)
				if client.focus then client.focus:move_to_tag(t) end
			end),
			tag_numkey(i, { env.mod, "Control", "Shift" }, function(t)
				if client.focus then client.focus:toggle_tag(t) end
			end)
		)
	end

	-- make fake keys with description special for key helper widget
	self.fake.tagkeys = {
		{
			{ env.mod }, line1_symb, nil,
			{ description = L("Switch to tag"), group = L("Tag Control"), keyset = numkeys }
		},
		{
			{ env.mod, "Control" }, line1_symb, nil,
			{ description = L("Toggle tag"), group = L("Tag Control"), keyset = numkeys }
		},
		{
			{ env.mod, "Shift" }, line1_symb, nil,
			{ description = L("Move client to tag"), group = L("Tag Control"), keyset = numkeys }
		},
		{
			{ env.mod, "Control", "Shift" }, line1_symb, nil,
			{ description = L("Toggle client on tag"), group = L("Tag Control"), keyset = numkeys }
		},
	}

	-- Mouse bindings (informativas: no tienen tecla; se listan con nombre de botón)
	self.fake.mouse = {
		{
			{ env.mod }, "Ratón-1", nil,
			{ description = L("Drag: move window"), group = L("Mouse") }
		},
		{
			{ env.mod }, "Ratón-3", nil,
			{ description = L("Drag: resize window"), group = L("Mouse") }
		},
		{
			{}, "Ratón-8", nil,
			{ description = L("Close window (except 'game' tag)"), group = L("Mouse") }
		},
		{
			{}, "Ratón-1", nil,
			{ description = L("Focus window (click)"), group = L("Mouse") }
		},
		{
			{}, "Ratón-3", nil,
			{ description = L("Main menu (click on desktop)"), group = L("Mouse") }
		},
		{
			{}, "Rueda", nil,
			{ description = L("Switch tag (wheel on desktop)"), group = L("Mouse") }
		},
	}

	-- Build visual popup data from real key definitions (includes keychain actions).
	do
		local keychain_flat = {}
		for _, prefix in ipairs(keyseq[3] or {}) do
			local submods = prefix[1] or {}
			local subkey = prefix[2] or ""
			for _, action in ipairs(prefix[3] or {}) do
				local meta = action[4]
				if type(meta) == "table" and meta.description and meta.description ~= "" then
					table.insert(keychain_flat, {
						awful.util.table.join(keyseq[1] or {}, submods),
						string.format("%s %s %s", tostring(keyseq[2] or ""), tostring(subkey), tostring(action[2] or "")),
						nil,
						{
							description = tostring(meta.description),
							group = "Keychain (Mod+c)",
							keyset = { tostring(action[2] or "") },
						},
					})
				end
			end
		end

		project_hotkeys_pack = awful.util.table.join(
			self.raw.root, self.raw.client, self.fake.tagkeys, self.fake.mouse, keychain_flat,
			-- Teclas modales de layout (solo informativas; activas dentro de Mod+F2)
			periodic_popup.strip_run(layout_tile),
			periodic_popup.strip_run(layout_grid_move), periodic_popup.strip_run(layout_grid_resize),
			periodic_popup.strip_run(layout_map_layout), periodic_popup.strip_run(layout_map_resize)
		)
	end

	-- Regenera ATAJOS.md desde los datos reales: echo 'JIYU_DUMP_HOTKEYS()' | awesome-client
	JIYU_DUMP_HOTKEYS = function(path)
		return periodic_popup.dump_md(project_hotkeys_pack, path)
	end

	-- Hotkeys helper setup
	--------------------------------------------------------------------------------
	redflat.float.hotkeys:set_pack(L("Main"), awful.util.table.join(self.raw.root, self.raw.client, self.fake.tagkeys), 2)

	-- Mouse buttons
	--------------------------------------------------------------------------------
	local function game_safe_kill(c)
		local current_tag = awful.screen.focused().selected_tag
		if current_tag and current_tag.name and current_tag.name:lower() ~= "game" then
			c:kill()
		end
	end

	self.mouse.client = awful.util.table.join(
		awful.button({}, 1, function (c) client.focus = c; c:raise() end),
		awful.button({}, 2, awful.mouse.client.move),
		awful.button({ env.mod }, 3, awful.mouse.client.resize),
		awful.button({}, 8, game_safe_kill)
	)

	-- Set root hotkeys
	--------------------------------------------------------------------------------
	root.keys(self.keys.root)
	root.buttons(self.mouse.root)

	-- Optional: show project cheatsheet on Awesome start/reload.
	-- Keep a timer reference to avoid GC before first tick.
	if show_hotkeys_on_startup then
		self._startup_popup_timer = gears.timer({
			timeout = 3,
			autostart = true,
			single_shot = true,
			callback = function()
				periodic_popup.show(project_hotkeys_pack)
			end,
		})
	end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return hotkeys
