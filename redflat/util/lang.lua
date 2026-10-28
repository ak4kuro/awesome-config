-----------------------------------------------------------------------------------------------------------------------
--  Traducción opcional vía Jiyu.locale (sin dependencia dura: si no existe el módulo, devuelve la cadena original).     --
-----------------------------------------------------------------------------------------------------------------------
local M = {}

function M.t(s)
	if type(s) ~= "string" then
		return s
	end
	local ok, loc = pcall(require, "Jiyu.locale")
	if ok and loc and loc.t then
		return loc.t(s)
	end
	return s
end

return M
