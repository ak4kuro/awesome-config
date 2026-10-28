-----------------------------------------------------------------------------------------------------------------------
--                                                   Scratchpads                                                      --
-----------------------------------------------------------------------------------------------------------------------
-- Ventanas ocultas que aparecen con hotkey (terminal, calculator, notes)
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local root = root

local scratchpads = {}

-- Configuración de scratchpads
local scratchpad_config = {
	terminal = {
		command = "xfce4-terminal --name scratchpad_terminal",
		class = "scratchpad_terminal",
		screen = awful.screen.focused(),
		tag = awful.screen.focused().selected_tag,
	},
	calculator = {
		command = "galculator --name scratchpad_calculator",
		class = "scratchpad_calculator",
		screen = awful.screen.focused(),
		tag = awful.screen.focused().selected_tag,
	},
	notes = {
		command = "mousepad --name scratchpad_notes",
		class = "scratchpad_notes",
		screen = awful.screen.focused(),
		tag = awful.screen.focused().selected_tag,
	},
}

-- Función para mostrar/ocultar scratchpad
local function toggle_scratchpad(config)
	local screen = config.screen or awful.screen.focused()
	local tag = config.tag or screen.selected_tag

	-- Buscar si ya existe el scratchpad por WM_CLASS
	local client = nil
	for c in awful.client.iterate(function(c)
		return c.class == config.class or c.instance == config.class
	end) do
		client = c
		break
	end

	if client then
		-- Si existe, mostrar/ocultar
		if client:isvisible() then
			client.hidden = true
			client.minimized = true
		else
			client.hidden = false
			client.minimized = false
			client:tags({ tag })
			client:raise()
			client.focus = true
		end
	else
		-- Si no existe, lanzar
		print("Launching scratchpad: " .. config.command)
		awful.spawn(config.command, {
			tag = tag,
			screen = screen,
		})
	end
end

-- Función pública para toggle scratchpad
function scratchpads:toggle(name)
	if scratchpad_config[name] then
		toggle_scratchpad(scratchpad_config[name])
	end
end

-- Inicializar scratchpads
function scratchpads.init()
	-- Los hotkeys se registran en keys-config.lua para centralizar la gestión
end

return scratchpads
