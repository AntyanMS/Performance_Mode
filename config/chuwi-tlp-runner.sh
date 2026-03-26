#!/usr/bin/env bash
# Ярлык GNOME: zenity + sudo -A (без pkexec и без окна терминала).
set -euo pipefail

MODE="${1:-}"
[[ -n "$MODE" ]] || exit 1

if [[ "$(id -u)" -eq 0 ]]; then
  exec /usr/local/bin/chuwi-tlp-notify-root "$MODE"
fi

export SUDO_ASKPASS=/usr/local/bin/chuwi-askpass
if [[ ! -x "$SUDO_ASKPASS" ]]; then
  /usr/bin/zenity --error --text="Не найден /usr/local/bin/chuwi-askpass. Перезапустите install.sh." 2>/dev/null || true
  exit 1
fi

set +e
sudo -A /usr/local/bin/chuwi-tlp-notify-root "$MODE"
RC=$?
set -e

if [[ "$RC" -ne 0 ]]; then
  /usr/bin/zenity --error --text="TLP: отмена, неверный пароль или нет прав sudo." 2>/dev/null || true
  exit "$RC"
fi
