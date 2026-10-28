# Notas del proyecto (Awesome WM 4.3 — Jiyu/RedFlat)

Config de Awesome WM 4.3 sobre Lua 5.3. Layout base: RedFlat + capa propia en `Jiyu/`.

## Verificación

```bash
bash tests/run.sh          # sintaxis (loadfile) + awesome --check + test de temas (+ luacheck si está)
awesome --check            # solo sintaxis del config
echo 'awesome.restart()' | awesome-client   # recargar en vivo
```

## Regenerar ATAJOS.md

`ATAJOS.md` se genera desde los datos reales de atajos (fuente única de verdad):

```bash
echo 'JIYU_DUMP_HOTKEYS()' | awesome-client
```

No editarlo a mano — se sobrescribe.

## Quirks de Awesome 4.3 (importantes, fáciles de romper)

- `wibox.container.margin` **no** acepta `margins = {left=…, right=…, top=…, bottom=…}` como tabla
  (falla con `attempt to perform arithmetic on a table value` y el widget no se pinta).
  Usar propiedades sueltas `left=…, right=…` o un número `margins=8`.
- `wibox.layout.align` solo usa los índices 1, 2, 3 (top/middle/bottom u left/middle/right).
  Un `nil` intermedio crea un hueco y el widget en índice 4 **se ignora**.
- `wibox.layout.align` no tiene `spacing` en 4.3.
- `awful.screen.focused()` sigue la pantalla del ratón (no el foco de teclado).
- En entradas de keys con callbacks press/release puede haber huecos: la metadata
  `{description=…}` puede no ser `entry[#entry]` — buscar la tabla con `.description`.

## Reglas de markup Pango

Todo texto externo que entre en `set_markup`/markup debe escaparse
(`gears.string.xml_escape` o `awful.util.escape`): títulos de ventana
(`titlebar-config.lua`), contenido del portapapeles (`clipboard.lua`), etc.
Sin escapar produce `Entity did not end with a semicolon` en `~/.xsession-errors`.

## Estructura

- `Jiyu/keys-config.lua` — definición de atajos y bindings de ratón.
- `Jiyu/periodic-popup.lua` — tabla periódica de atajos (popup `Mod4+Shift+F1`).
- `Jiyu/locale.lua` + `Jiyu/locale/strings_{es,en}.lua` — traducciones vía `L()`,
  con fallback al literal en inglés.
- `themes/` — tema visual (Jiyu / JiyuLight).
