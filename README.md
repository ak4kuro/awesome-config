# AwesomeWM Jiyu - Configuración personalizada

Configuración personalizada de AwesomeWM basada en el tema **Jiyu** con el toolkit **redflat**. Incluye widgets de escritorio, dock flotante, historial de portapapeles, cambio de tema con hotkey y más.

---

## Requisitos

Ejecuta el script de instalación de dependencias:

```bash
bash install-deps.sh
```

### Dependencias principales

- **AwesomeWM** + X11 básico (`xorg-server`, `xorg-xrandr`, `arandr`)
- **Audio**: PipeWire + pactl
- **Red**: NetworkManager + nm-applet
- **Aplicaciones XFCE**: xfce4-terminal, galculator, mousepad, thunar
- **Utilidades**: xsel, xclip, feh, scrot, pavucontrol, blueman, picom, curl

---

## Estructura del proyecto

```
~/.config/awesome/
├── rc.lua                    # Punto de entrada, selección de tema
├── install-deps.sh           # Script de instalación de dependencias
├── Jiyu/
│   ├── rc-Jiyu.lua           # Configuración principal (panel, widgets, layouts)
│   ├── keys-config.lua       # Hotkeys y mouse bindings
│   ├── env-config.lua        # Variables de entorno y wrappers
│   ├── desktop-config.lua    # Widgets de escritorio (clima, red)
│   ├── dock.lua              # Dock flotante estilo macOS
│   ├── clipboard.lua         # Historial de portapapeles con popup
│   ├── theme-switcher.lua    # Cambiador de tema claro/oscuro con hotkey
│   ├── lang-switcher.lua     # Cambiador de idioma (es/en) con hotkey
│   ├── autostart-config.lua  # Aplicaciones al inicio
│   └── animations.lua        # Animaciones de ventana
├── redflat/                  # Toolkit de widgets y utilidades
└── themes/
    ├── Jiyu/                 # Tema oscuro (rojo/gris)
    └── JiyuLight/            # Tema claro (blanco/azul)
```

---

## Tema claro/oscuro

### Selección fija

Edita `rc.lua` y cambia la variable:

```lua
local USE_LIGHT_THEME = true   -- true = claro, false = oscuro
```

### Cambio con hotkey

Pulsa **Mod4+Alt+T** para alternar entre tema claro y oscuro. AwesomeWM se reiniciará automáticamente aplicando el nuevo tema.

---

## Multiidioma (es/en)

### Selección fija

Edita `rc.lua` y cambia la variable:

```lua
local UI_LANG = "auto"   -- "auto" (detecta LANG), "es" o "en"
```

### Cambio con hotkey

Pulsa **Mod4+Alt+L** para alternar entre español e inglés. AwesomeWM se reiniciará automáticamente aplicando el nuevo idioma.

El sistema traduce:
- Todos los atajos de teclado y la tabla periódica
- Menús de apagado (oblogout)
- Notificaciones del cambiador de tema e idioma
- Widget de portapapeles
- Condiciones meteorológicas del widget de clima
- Mensajes del sistema (errores, alertas, etc.)

Para añadir traducciones nuevas, edita `Jiyu/locale/strings_es.lua`.

---

## Atajos de teclado importantes

> **Mod4** = tecla Super (Windows) · **Mod1** = Alt · **Shift** = Mayús

### Aplicaciones

| Atajo | Acción |
|-------|--------|
| `Mod4+Return` | Abrir terminal |
| `Mod4+d` | Lanzador de aplicaciones |
| `Mod4+s` | Menú principal |
| `Mod4+p` | Caja de prompt |
| `Mod4+g` | Lanzador rápido |

### Dock

| Atajo | Acción |
|-------|--------|
| `Mod4+Shift+D` | Mostrar/ocultar dock flotante |

### Portapapeles, Tema e Idioma

| Atajo | Acción |
|-------|--------|
| `Mod4+Alt+C` | Historial del portapapeles |
| `Mod4+Alt+T` | Cambiar tema claro/oscuro |
| `Mod4+Alt+L` | Cambiar idioma (es/en) |

### Navegación de ventanas

| Atajo | Acción |
|-------|--------|
| `Mod4+l` | Ventana a la derecha |
| `Mod4+j` | Ventana a la izquierda |
| `Mod4+i` | Ventana arriba |
| `Mod4+k` | Ventana abajo |
| `Mod4+u` | Cliente urgente |
| `Mod4+a` | Cambiar entre apps (tag actual) |
| `Mod4+Shift+A` | Cambiar entre apps (todos los tags) |

### Navegación de tags

| Atajo | Acción |
|-------|--------|
| `Mod4+Tab` | Tag anterior (historial) |
| `Mod4+Right` | Tag siguiente |
| `Mod4+Left` | Tag anterior |
| `Mod4+Up` | Línea superior de tags |
| `Mod4+Down` | Línea inferior de tags |
| `Mod4+Space` | Cambiar línea de tags |
| `Mod4+1..9` | Ir al tag N (línea 1) |
| `Mod4+q..o` | Ir al tag N (línea 2) |

### Control de ventanas

| Atajo | Acción |
|-------|--------|
| `Mod4+f` | Pantalla completa |
| `Mod4+F4` | Cerrar ventana |
| `Mod4+n` | Minimizar |
| `Mod4+m` | Maximizar |
| `Mod4+c` | Secuencia de teclas (keychain) |
| `Mod4+b` | Control de titlebar (hold) |
| `Mod4+h` | Control de ventana flotante (hold) |
| `Mod4+F2` | Control de tiling (hold) |

### Widgets

| Atajo | Acción |
|-------|--------|
| `Mod4+/` | Top procesos (CPU) |
| `Mod4+,` | Info de actualizaciones del sistema |
| `Mod4+`` | Minitray |
| `Mod4+Ctrl+N` | Gestor de red (Wi-Fi/cable) |
| `Mod4+z` | Pantalla de logout |
| `Mod4+Shift+X` | Menú de apagado |

### Layouts

| Atajo | Acción |
|-------|--------|
| `Mod4+v` | Menú de layout |
| `Mod4+]` | Layout siguiente |
| `Mod4+[` | Layout anterior |

### Volumen y brillo

| Atajo | Acción |
|-------|--------|
| `Subir volumen` | Aumentar volumen |
| `Bajar volumen` | Reducir volumen |
| `Silenciar` | Mutear audio |
| `Ctrl+Silenciar` | Mutear micrófono |
| `Subir brillo` | Aumentar brillo |
| `Bajar brillo` | Reducir brillo |

### Reproductor de audio

| Atajo | Acción |
|-------|--------|
| `Mod4+.` | Mostrar/ocultar reproductor |
| `Play/Pause` | Reproducir/pausar |
| `Siguiente` | Pista siguiente |
| `Anterior` | pista anterior |

### Ayuda

| Atajo | Acción |
|-------|--------|
| `Mod4+Shift+F1` | Tabla periódica de atajos (popup visual) |
| `Esc` | Cerrar popup de atajos |

---

## Widgets de escritorio

### Clima
- Muestra condición meteorológica y temperatura en el escritorio
- Ciudad configurable manualmente o por IP
- Condiciones traducidas al español con iconos emoji
- Transparente, adaptado al tema claro/oscuro

### Batería
- Porcentaje y estado en el panel
- Tiempo restante en el tooltip
- Alertas a los 5%, 10%, 15% y 20%

### Red
- Velocidad de subida/bajada en tiempo real (1s)
- Tooltip con velocidad formateada e interfaz

### Monitor de recursos
- CPU y RAM en tiempo real en el panel

---

## Dock flotante

Dock estilo macOS en la parte superior con 8 iconos:
- Librewolf, Terminal, Files, Text Editor, Calculator, VS Code, Discord, Spotify

Para añadir/quitar apps, edita la tabla `apps` en `Jiyu/dock.lua`.

---

## Historial de portapapeles

- Captura el portapapeles cada 2 segundos
- Máximo 30 entradas
- Popup con lista seleccionable
- Click para copiar cualquier entrada
- Usa `xclip` o `xsel` según disponibilidad

---

## Auto-start

Aplicaciones que se inician automáticamente:
- Polkit-gnome (autenticación)
- Picom (compositor)
- nm-applet (red)
- Pragha (reproductor)
- Setxkbmap (español/inglés con Alt+Shift)
- Scripts de entorno personalizados

Edita `Jiyu/autostart-config.lua` para modificar.

---

## Mejoras implementadas

1. **Detección de tema claro/oscuro** automática o manual
2. **Cambio de tema con hotkey** (Mod4+Alt+T)
3. **Multiidioma completo (es/en)** con cambio por hotkey (Mod4+Alt+L)
4. **Widget de clima** con traducción condicional al español e iconos emoji
5. **Dock flotante** adaptado al tema con 8 iconos
6. **Historial de portapapeles** con popup y xsel/xclip
8. **Widget de batería** con alertas y tiempo restante
9. **Monitor de red** en tiempo real (1s)
10. **Animaciones suaves** para cambios de ventana
11. **Efecto blur** en popups
12. **Notificaciones personalizadas** con mejor diseño
13. **Tabla periódica de atajos** visual (popup)
14. **Auto-start** de aplicaciones configurado
15. **Hotkeys centralizados** sin duplicados en keys-config.lua
16. **Script de instalación** de dependencias
