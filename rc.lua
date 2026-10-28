-----------------------------------------------------------------------------------------------------------------------
--                                                   Base setup                                                      --
-----------------------------------------------------------------------------------------------------------------------

-- Tema: true = JiyuLight (blanco/azul), false = Jiyu (rojo/gris oscuro)
-- Cambiar a true para detección automática, false para modo oscuro manual
local USE_LIGHT_THEME = false

-- Idioma de la interfaz: "auto" (detecta LANG), "es" o "en"
local UI_LANG = "es"

-- Configuration file selection
-----------------------------------------------------------------------------------------------------------------------
local rc = "Jiyu.rc-Jiyu"

-- Pasar la configuración del tema e idioma al rc-Jiyu
_G.JIYU_CONFIG = { USE_LIGHT_THEME = USE_LIGHT_THEME, UI_LANG = UI_LANG }

require(rc)
