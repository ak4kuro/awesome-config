-- RedFlat util submodule

local io = io
local assert = assert

local read = {}

-- Functions
-----------------------------------------------------------------------------------------------------------------------
function read.file(path)
	local file = io.open(path)

	if file then
		local output = file:read("*a")
		file:close()
		return output
	else
		return nil
	end
end

function read.output(cmd)
	local file = io.popen(cmd, "r")
	if not file then
		return nil
	end
	local output = file:read("*all")
	file:close()
	return output
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return read
