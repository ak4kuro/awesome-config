#!/usr/bin/env bash
# Verificación del config de Awesome: sintaxis (loadfile) + awesome -k + temas + lint opcional.
set -uo pipefail
cd "$(dirname "$0")/.."

LUA_BIN=""
for c in luajit lua5.4 lua5.3 lua5.2 lua5.1 lua; do
	if command -v "$c" >/dev/null 2>&1; then LUA_BIN="$c"; break; fi
done

fail=0

if [ -n "$LUA_BIN" ]; then
	echo "== sintaxis ($LUA_BIN loadfile) =="
	while IFS= read -r -d '' f; do
		if ! "$LUA_BIN" -e "assert(loadfile('$f'))" 2>/dev/null; then
			echo "  SINTAXIS KO: $f"
			"$LUA_BIN" -e "assert(loadfile('$f'))" || true
			fail=1
		fi
	done < <(find . -name '*.lua' -not -path './.git/*' -print0)
	[ "$fail" -eq 0 ] && echo "  todos los .lua compilan"
else
	echo "== sintaxis =="
	echo "  no hay intérprete lua en PATH — omitido (awesome --check sigue cubriendo el config)"
fi

echo "== awesome --check =="
if command -v awesome >/dev/null 2>&1; then
	awesome --check || fail=1
else
	echo "  awesome no en PATH — omitido"
fi

echo "== theme load test =="
if [ -n "$LUA_BIN" ]; then
	"$LUA_BIN" tests/theme_load.lua "$PWD" || fail=1
else
	echo "  sin intérprete lua — omitido"
fi

echo "== luacheck (opcional) =="
if command -v luacheck >/dev/null 2>&1; then
	luacheck . || fail=1
else
	echo "  luacheck no instalado — omitido"
fi

if [ "$fail" -ne 0 ]; then
	echo "== FALLOS =="
	exit 1
fi
echo "== OK =="
