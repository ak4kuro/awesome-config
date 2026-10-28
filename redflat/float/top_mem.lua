local base = require("redflat.float.top_base")
local tr = require("redflat.util.lang").t

return base.new({
	fixed_sort    = "mem",
	theme_key     = "float.top_mem",
	tip_title     = tr("Processes by memory"),
	peer_module   = "redflat.float.top_cpu",
})
