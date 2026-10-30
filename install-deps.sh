#!/usr/bin/env bash
# Instala dependencias (pacman) para esta configuración de Awesome WM + redflat.
# Uso: ./install-deps.sh   o   bash install-deps.sh
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
	echo "Se necesita sudo para instalar paquetes." >&2
	exit 1
fi

run_pacman() {
	if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
		pacman "$@"
	else
		sudo pacman "$@"
	fi
}

# Paquetes usados por rc.lua (Jiyu), redflat y autostart-config.
# Opcionales comentados al final (GPU Optimus, AUR, etc.).
PACKAGES=(
	# Gestor de ventanas y X11 básico
	awesome
	xorg-server
	xorg-xrandr
	arandr
	xorg-setxkbmap
	xorg-xbacklight
	# Red y bandeja
	networkmanager
	network-manager-applet
	iproute2
	# Audio (PipeWire + pactl para el widget de volumen; pulse.lua admite pactl)
	pipewire
	pipewire-pulse
	wireplumber
	libpulse
	# Monitoreo y utilidades que invoca redflat/system.lua y widgets
	lm_sensors
	smartmontools
	vnstat
	pacman-contrib
	# Perfil de energía (menú clic derecho en batería)
	power-profiles-daemon
	# Entorno por defecto (env-config): terminal, browser, file manager, editor
	alacritty
	nemo
	geany
	python
	curl
	dbus
	# Screen locker: xsecurelock + xss-lock (auto-bloqueo por inactividad/suspend)
	xsecurelock
	xss-lock
	# Compositor: transparencias, sombras, fade
	picom
	# Daemon de notificaciones
	dunst
	# Luz nocturna (night light)
	gammastep
	# Capturas de pantalla
	scrot
	# MPRIS para la barra de escritorio (redflat/desktop/playerbar.lua)
	playerctl
	# Autostart: applets de bandeja
	blueman
	# Clipboard history
	xsel
	# Utilidades adicionales
	xclip
	feh
	pavucontrol
	# Brillo: brightnessctl es más fiable que xbacklight en portátiles modernos
	brightnessctl
	# xdotool: foco X11 real durante drag-to-focus (signals-config.lua)
	xdotool
	# Fuentes de respaldo (el tema «Jiyu» usa «Play»; suele hacer falta instalarla aparte o desde AUR)
	noto-fonts
)

echo "Instalando paquetes con pacman (--needed)..."
run_pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo ""
echo "=== Post-instalación (recomendado) ==="
echo "1) Sensores CPU/ventilador:  sudo sensors-detect   (o --auto en sistemas sin interacción)"
echo "2) Red:  sudo systemctl enable --now NetworkManager"
echo "   Tráfico daily/monthly (vnstat):  sudo vnstat --add -i TU_IFACE   &&   sudo systemctl enable --now vnstat"
echo "3) Bluetooth:  sudo systemctl enable --now bluetooth"
echo "   Perfil de energía:  sudo systemctl enable --now power-profiles-daemon"
echo "4) Temperatura de disco (SMART): smartmontools ya está en la lista; hace falta leer el disco:"
echo "     sudo usermod -aG disk \"\$USER\"   (cierra sesión después)"
echo "5) Temperatura Wi‑Fi (si el chip la expone): paquete «lm_sensors» + «sensors-detect»; muchos adaptadores no reportan temp por software."
echo "6) Tema «Play»: si las etiquetas se ven mal, instala la fuente Play (p. ej. desde AUR) o cámbiala en themes/Jiyu/theme.lua"
echo "7) Brillo: instala brightnessctl (sudo pacman -S brightnessctl) si xbacklight no funciona"
echo "   Si las teclas de brillo no cambian nada, falta permiso de escritura en sysfs:"
echo "     sudo usermod -aG video \"\$USER\"   (cierra sesión después)"
echo "   O crea una regla udev:"
echo "     echo 'ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/bin/chgrp video /sys/class/backlight/%k/brightness\"' | sudo tee /etc/udev/rules.d/90-backlight.rules"
echo "     echo 'ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/bin/chmod g+w /sys/class/backlight/%k/brightness\"' | sudo tee -a /etc/udev/rules.d/90-backlight.rules"
echo "8) Speedtest: instala librespeed-cli (AUR) o speedtest-cli (AUR) para el botón de test de velocidad"
echo "9) Screen locker: xsecurelock + xss-lock ya están en la lista."
echo ""
echo "=== AUR (no en repos oficiales; instalar con yay/paru) ==="
echo "   guake       — terminal desplegable (dock + menú)"
echo "   librewolf   — navegador (dock + menú)"
echo "   code        — Visual Studio Code / VSCodium (dock)"
echo ""
echo "GPU híbrida NVIDIA (solo si usas Optimus y thermal.nvoptimus en el escritorio):"
echo "     # sudo pacman -S bumblebee nvidia-settings   # revisa que coincida con tu driver"
echo ""
echo "Listo."
