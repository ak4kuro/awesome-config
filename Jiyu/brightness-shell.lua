-----------------------------------------------------------------------------------------------------------------------
-- Shell helpers for brightness (brightnessctl → sysfs → xrandr).
-- Scripts planos para awful.spawn.easy_async_with_shell (sin bash -lc '...').
-----------------------------------------------------------------------------------------------------------------------

local M = {}

local CACHE_DIR = [[CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/awesome"
CACHE="$CACHE_DIR/xrandr_brightness"
mkdir -p "$CACHE_DIR" 2>/dev/null
]]

local APPLY = [[ok=0
if command -v brightnessctl >/dev/null 2>&1 && brightnessctl set "${p}%" >/dev/null 2>&1; then
  ok=1
fi
if [ "$ok" -ne 1 ]; then
  d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1)
  if [ -n "$d" ] && [ -w "$d/brightness" ]; then
    max=$(cat "$d/max_brightness")
    new=$(( (p * max + 50) / 100 ))
    [ "$new" -lt 0 ] && new=0
    [ "$new" -gt "$max" ] && new=$max
    echo "$new" > "$d/brightness" 2>/dev/null && ok=1
  fi
fi
if command -v xrandr >/dev/null 2>&1; then
  br=$(awk -v p="$p" "BEGIN{printf \"%.2f\", p/100}")
  for out in $(xrandr --current 2>/dev/null | awk "/ connected/{print \$1}"); do
    if xrandr --output "$out" --brightness "$br" >/dev/null 2>&1; then
      ok=1
    fi
  done
  [ "$ok" -eq 1 ] && echo "$p" > "$CACHE"
fi
echo "$p"
]]

local READ_CUR = [[cur=100
if command -v brightnessctl >/dev/null 2>&1; then
  c=$(brightnessctl get 2>/dev/null)
  m=$(brightnessctl max 2>/dev/null)
  if [ -n "$m" ] && [ "$m" -gt 0 ]; then
    cur=$((c * 100 / m))
  fi
elif d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); [ -n "$d" ] && [ -r "$d/brightness" ]; then
  max=$(cat "$d/max_brightness")
  c=$(cat "$d/brightness")
  cur=$(( (c * 100 + max / 2) / max ))
elif [ -f "$CACHE" ]; then
  cur=$(cat "$CACHE")
elif command -v xrandr >/dev/null 2>&1; then
  b=$(xrandr --verbose 2>/dev/null | awk "/ connected/{c=1} c&&/Brightness:/{print \$2; exit}")
  if [ -n "$b" ]; then
    cur=$(awk -v b="$b" "BEGIN{printf \"%d\", b*100+0.5}")
  fi
fi
[ -z "$cur" ] && cur=100
[ "$cur" -lt 1 ] && cur=1
[ "$cur" -gt 100 ] && cur=100
]]

M.READ_PCT = CACHE_DIR .. READ_CUR .. 'echo "$cur"' .. "\n"

function M.set_shell(pct)
	pct = math.floor(tonumber(pct) or 50)
	if pct < 1 then pct = 1 end
	if pct > 100 then pct = 100 end
	return string.format(
		"p=%d\n[ \"$p\" -lt 1 ] && p=1\n[ \"$p\" -gt 100 ] && p=100\n%s%s",
		pct, CACHE_DIR, APPLY
	)
end

function M.increase_shell(step)
	step = math.floor(tonumber(step) or 5)
	if step < 1 then step = 1 end
	return string.format(
		"step=%d\n[ \"$step\" -lt 1 ] && step=1\n%s%sp=$((cur + step))\n[ \"$p\" -gt 100 ] && p=100\n[ \"$p\" -lt 1 ] && p=1\n%s",
		step, CACHE_DIR, READ_CUR, APPLY
	)
end

function M.decrease_shell(step)
	step = math.floor(tonumber(step) or 5)
	if step < 1 then step = 1 end
	return string.format(
		"step=%d\n[ \"$step\" -lt 1 ] && step=1\n%s%sp=$((cur - step))\n[ \"$p\" -lt 1 ] && p=1\n[ \"$p\" -gt 100 ] && p=100\n%s",
		step, CACHE_DIR, READ_CUR, APPLY
	)
end

local function pct_esc(s)
	return (s:gsub("%%", "%%%%"))
end

M.INCREASE_FMT = "step=%s\n[ \"$step\" -lt 1 ] && step=1\n"
	.. pct_esc(CACHE_DIR)
	.. pct_esc(READ_CUR)
	.. "p=$((cur + step))\n[ \"$p\" -gt 100 ] && p=100\n[ \"$p\" -lt 1 ] && p=1\n"
	.. pct_esc(APPLY)

M.DECREASE_FMT = "step=%s\n[ \"$step\" -lt 1 ] && step=1\n"
	.. pct_esc(CACHE_DIR)
	.. pct_esc(READ_CUR)
	.. "p=$((cur - step))\n[ \"$p\" -lt 1 ] && p=1\n[ \"$p\" -gt 100 ] && p=100\n"
	.. pct_esc(APPLY)

return M
