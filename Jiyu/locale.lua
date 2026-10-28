-----------------------------------------------------------------------------------------------------------------------
--  Idioma de la interfaz Jiyu (es / en)                                                                              --
--  env:init({ locale = "auto" | "es" | "en" }) — "auto" usa LANG (es* → español, resto → inglés).                    --
--  Uso: L("Texto en inglés") — en español se busca en locale/strings_es.lua; en inglés en strings_en.lua o el propio  --
--  literal del código. Añade entradas en strings_en.lua solo si quieres sobrescribir el inglés por defecto.          --
-----------------------------------------------------------------------------------------------------------------------

local M = {}

local current = "en"

local strings_es = require("Jiyu.locale.strings_es")
local strings_en = require("Jiyu.locale.strings_en")

local function detect_lang()
	local lang = os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or os.getenv("LANG") or ""
	lang = lang:lower()
	if lang:match("^es") then
		return "es"
	end
	return "en"
end

function M.init(args)
	args = args or {}
	local want = args.locale
	if want == "es" or want == "en" then
		current = want
	elseif want == "auto" or want == nil then
		current = detect_lang()
	else
		current = detect_lang()
	end
end

function M.get_lang()
	return current
end

function M.t(s)
	if type(s) ~= "string" then
		return s
	end
	if current == "es" then
		return strings_es[s] or s
	end
	return strings_en[s] or s
end

return M
