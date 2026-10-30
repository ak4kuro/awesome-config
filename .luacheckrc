-- luacheck para config de Awesome WM
std = "lua53+luajit"

-- Globals inyectados por Awesome en tiempo de ejecución
read_globals = {
	"awesome", "client", "screen", "tag", "mouse", "root",
}

-- Globals que el propio config define
globals = {
	"JIYU_CONFIG",
	"JIYU_DUMP_HOTKEYS",
}

ignore = {
	"212", -- argumento de callback sin usar
	"213", -- variable de bucle sin usar
	"542", -- if/branch vacío (stubs intencionados)
}

max_line_length = false
exclude_files = {}
