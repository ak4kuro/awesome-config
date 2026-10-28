-----------------------------------------------------------------------------------------------------------------------
--                                                   Window animations                                                --
-----------------------------------------------------------------------------------------------------------------------
-- Animaciones suaves para cambios de ventana
-----------------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local animations = {}

-- Configuración de animaciones
local config = {
	transition_duration = 0.2, -- segundos
	transition_step = 0.02, -- segundos
}

-- Animación de opacidad al enfocar ventana
function animations.setup_focus_animation()
	client.connect_signal("focus", function(c)
		if not c.fullscreen then
			c.opacity = 1
		end
	end)

end

-- Animación de minimización
function animations.setup_minimize_animation()
	client.connect_signal("property::minimized", function(c)
		if not c.minimized then
			-- Ventana restaurada: restaurar opacidad
			c.opacity = 1
		end
	end)
end

-- Animación de maximización
function animations.setup_maximize_animation()
	client.connect_signal("property::maximized", function(c)
		if c.maximized then
			-- Ventana maximizada: opacidad completa
			c.opacity = 1
		end
	end)
end

-- Inicializar todas las animaciones
function animations.init()
	animations.setup_focus_animation()
	animations.setup_minimize_animation()
	animations.setup_maximize_animation()
end

return animations
