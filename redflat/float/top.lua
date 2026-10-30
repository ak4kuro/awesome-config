-----------------------------------------------------------------------------------------------------------------------
--  Compatibilidad: delega a top_cpu / top_mem (dos wibox independientes, cada uno con su Kill)                       --
-----------------------------------------------------------------------------------------------------------------------

local cpu = require("redflat.float.top_cpu")
local mem = require("redflat.float.top_mem")

local top = {}

function top:show(srt)
	if srt == "mem" then
		mem:show()
	else
		cpu:show()
	end
end

function top:hide()
	cpu:hide()
	mem:hide()
end

function top:set_keys(keys, layout)
	cpu:set_keys(keys, layout)
	mem:set_keys(keys, layout)
end

top.keys = cpu.keys
top._fake_keys = cpu._fake_keys

return top
