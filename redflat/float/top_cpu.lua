local base = require("redflat.float.top_base")
local tr = require("redflat.util.lang").t

return base.new({
	fixed_sort    = "cpu",
	theme_key     = "float.top_cpu",
	tip_title     = tr("Processes by CPU"),
	peer_module   = "redflat.float.top_mem",
})
