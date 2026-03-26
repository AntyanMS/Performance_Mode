#!/usr/bin/env bash
# Только root (вызывается из chuwi-tlp-runner через sudo -A).
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || exit 1

MODE="${1:-}"

# Кто вызвал sudo
INVOKER_UID="${SUDO_UID:-}"
if [[ -z "$INVOKER_UID" && -n "${PKEXEC_UID:-}" ]]; then
  INVOKER_UID="$PKEXEC_UID"
fi
if [[ -z "$INVOKER_UID" ]]; then
  exit 1
fi

INVOKER_HOME=$(getent passwd "$INVOKER_UID" | cut -d: -f6)
INVOKER_NAME=$(getent passwd "$INVOKER_UID" | cut -d: -f1)
PM="${INVOKER_HOME}/power-mode.sh"
RU="/run/user/${INVOKER_UID}"

notify_user() {
  local title="$1" body="$2" urgency="${3:-normal}"
  local -a envcmd=(env "XDG_RUNTIME_DIR=${RU}" "DBUS_SESSION_BUS_ADDRESS=unix:path=${RU}/bus")

  if [[ -x /usr/bin/notify-send ]]; then
    if runuser -u "$INVOKER_NAME" -- "${envcmd[@]}" /usr/bin/notify-send -a "TLP" "$title" "$body" \
      -i preferences-system-power -u "$urgency" 2>/dev/null; then
      return 0
    fi
    sudo -u "$INVOKER_NAME" "${envcmd[@]}" /usr/bin/notify-send -a "TLP" "$title" "$body" \
      -i preferences-system-power -u "$urgency" 2>/dev/null && return 0
  fi

  if command -v gdbus >/dev/null 2>&1; then
    runuser -u "$INVOKER_NAME" -- "${envcmd[@]}" gdbus call --session \
      --dest org.freedesktop.Notifications \
      --object-path /org/freedesktop/Notifications \
      --method org.freedesktop.Notifications.Notify \
      "TLP" 0 "preferences-system-power" "$title" "$body" "[]" "{}" 5000 2>/dev/null && return 0
  fi
  return 1
}

if [[ ! -x "$PM" ]]; then
  notify_user "TLP" "Не найден или не исполняемый: ${PM}" critical || true
  exit 1
fi

# Число потоков в eco — из той же константы, что в power-mode.sh (ECO_ONLINE_CPU_COUNT=N)
ECO_N=$(sed -n 's/^ECO_ONLINE_CPU_COUNT=//p' "$PM" 2>/dev/null | head -1 | tr -cd '0-9')
[[ -z "$ECO_N" ]] && ECO_N=4

case "$MODE" in
  eco|quiet|q)
    TITLE="Экономия (eco)"
    BODY="Минимум энергии: ${ECO_N} логических CPU, низкий потолок CPU (см. CPU_MAX в power-mode.sh), яркость ~1 %. Wi‑Fi и Bluetooth включены."
    ;;
  balanced|b)
    TITLE="Баланс"
    BODY="Половина потоков, потолок CPU ~36 % (от сети) / ~32 % (от батареи), яркость 30 %."
    ;;
  performance|p)
    TITLE="Максимум"
    BODY="Все потоки, governor performance, яркость 100 %."
    ;;
  reset|r)
    TITLE="TLP"
    BODY="Текущий профиль применён повторно (tlp start)."
    ;;
  *)
    notify_user "TLP" "Неизвестный режим: ${MODE:-пусто}" critical || true
    exit 1
    ;;
esac

set +e
OUT=$(bash "$PM" "$MODE" 2>&1)
RC=$?
set -e

if [[ "$RC" -eq 0 ]]; then
  notify_user "$TITLE" "$BODY" || true
else
  ERR=$(echo "$OUT" | tail -n 3 | tr '\n' ' ' | cut -c1-200)
  notify_user "TLP" "Режим «$MODE» не применён.${ERR:+ ($ERR)}" critical || true
  exit "$RC"
fi
