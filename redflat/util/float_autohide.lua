-----------------------------------------------------------------------------------------------------------------------
-- Cerrar flotantes tras N s con el ratón fuera del wibox (mouse::leave / enter)
-----------------------------------------------------------------------------------------------------------------------

local beautiful = require("beautiful")
local gears = require("gears")

local M = {}

--- Duración (s) del tramo final en que el wibox se va atenuando antes de cerrarse.
local WARN_DURATION = 1
--- Opacidad mínima alcanzada justo antes de cerrarse.
local MIN_OPACITY = 0.45
--- Intervalo (s) del timer de atenuación.
local FADE_TICK = 0.05

--- @param ctx tabla del módulo (calendar, top, netctl, …) donde guardar el timer
--- @param w wibox
--- @param args.timeout segundos (por defecto beautiful.float.autohide_timeout o 3)
--- @param args.hide función sin args que oculta el flotante
--- @param args.can_hide opcional: si devuelve false no se programa el cierre
function M.attach(ctx, w, args)
	if not w or not args or not args.hide then
		return
	end
	if ctx._float_autohide_attached then
		return
	end

	local timeout = args.timeout
	if timeout == nil and beautiful and beautiful.float then
		timeout = beautiful.float.autohide_timeout
	end
	timeout = timeout or 3

	local hide = args.hide
	local can_hide = args.can_hide or function()
		return true
	end

	local warn_duration = math.min(WARN_DURATION, timeout)

	local fade_t = gears.timer({ timeout = FADE_TICK })
	local function stop_fade()
		fade_t:stop()
		if w.opacity ~= 1 then
			w.opacity = 1
		end
	end
	fade_t:connect_signal("timeout", function()
		local remaining = (w._autohide_deadline or 0) - os.clock()
		if remaining <= 0 then
			stop_fade()
			return
		end
		if remaining <= warn_duration then
			local frac = remaining / warn_duration -- 1 → 0
			w.opacity = MIN_OPACITY + (1 - MIN_OPACITY) * frac
		else
			w.opacity = 1
		end
	end)

	local warn_t = gears.timer({ timeout = math.max(timeout - warn_duration, 0) })
	local t = gears.timer({ timeout = timeout })

	t:connect_signal("timeout", function()
		t:stop()
		warn_t:stop()
		stop_fade()
		if w.visible and can_hide() then
			hide()
		end
	end)

	warn_t:connect_signal("timeout", function()
		warn_t:stop()
		if not (w.visible and can_hide()) then
			return
		end
		w._autohide_deadline = os.clock() + warn_duration
		fade_t:start()
	end)

	w:connect_signal("mouse::leave", function()
		if not can_hide() then
			return
		end
		t:stop()
		warn_t:stop()
		stop_fade()
		t:start()
		warn_t:start()
	end)

	w:connect_signal("mouse::enter", function()
		t:stop()
		warn_t:stop()
		stop_fade()
	end)

	ctx._float_autohide_timer = t
	ctx._float_autohide_warn_timer = warn_t
	ctx._float_autohide_fade_timer = fade_t
	ctx._float_autohide_wibox = w
	ctx._float_autohide_attached = true
end

function M.stop(ctx)
	if ctx._float_autohide_timer then
		ctx._float_autohide_timer:stop()
	end
	if ctx._float_autohide_warn_timer then
		ctx._float_autohide_warn_timer:stop()
	end
	if ctx._float_autohide_fade_timer then
		ctx._float_autohide_fade_timer:stop()
	end
	if ctx._float_autohide_wibox and ctx._float_autohide_wibox.opacity ~= 1 then
		ctx._float_autohide_wibox.opacity = 1
	end
end

return M
