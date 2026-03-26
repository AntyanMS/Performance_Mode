#!/usr/bin/env bash
# Установка TLP и профилей Chuwi CoreBook X под конкретного пользователя (Ubuntu 24.04).
# Запуск: ./install.sh   или   sudo ./install.sh
# Другой пользователь:   sudo TARGET_USER="логин" ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PURGE_PPD="${PURGE_PPD:-0}"
for arg in "$@"; do
  case "$arg" in
    --purge-power-profiles) PURGE_PPD=1 ;;
    -h|--help)
      echo "Использование: $0 [--purge-power-profiles]"
      echo "  --purge-power-profiles  полностью удалить пакет power-profiles-daemon (опционально)"
      exit 0
      ;;
  esac
done

TARGET_USER="${TARGET_USER:-${SUDO_USER:-$USER}}"
if [[ "$TARGET_USER" == "root" ]]; then
  echo "Ошибка: не удалось определить целевого пользователя. Запустите не от root, либо:"
  echo "  sudo TARGET_USER=\"логин_в_системе\" $0"
  exit 1
fi

if ! TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)" || [[ -z "$TARGET_HOME" ]]; then
  echo "Ошибка: пользователь $TARGET_USER не найден в системе."
  exit 1
fi

echo ">>> Целевой пользователь: $TARGET_USER (HOME=$TARGET_HOME)"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo ">>> Запрос прав sudo для установки пакетов и записи в /etc …"
  exec sudo env TARGET_USER="$TARGET_USER" PURGE_PPD="$PURGE_PPD" bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

if ! grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
  echo "Предупреждение: скрипт рассчитан на Ubuntu 24.04; продолжаем на свой риск."
fi

echo ">>> Отключение штатного power-profiles-daemon (конфликтует с TLP) …"
if systemctl list-unit-files 2>/dev/null | grep -q '^power-profiles-daemon\.service'; then
  systemctl stop power-profiles-daemon.service 2>/dev/null || true
  systemctl disable power-profiles-daemon.service 2>/dev/null || true
  systemctl mask power-profiles-daemon.service 2>/dev/null || true
  echo "    Сервис остановлен, отключён и замаскирован."
else
  echo "    Юнит power-profiles-daemon не найден (возможно, уже удалён)."
fi

if [[ "$PURGE_PPD" == "1" ]]; then
  echo ">>> Удаление пакета power-profiles-daemon …"
  apt-get remove -y --purge power-profiles-daemon 2>/dev/null || true
fi

echo ">>> Обновление индекса пакетов и установка TLP …"
apt-get update -qq
apt-get install -y tlp tlp-rdw libnotify-bin zenity

echo ">>> Включение сервиса TLP …"
systemctl enable tlp.service
systemctl start tlp.service || true

echo ">>> Копирование /etc/tlp.d/98-chuwi-radios.conf …"
install -m 0644 "$SCRIPT_DIR/config/tlp/98-chuwi-radios.conf" /etc/tlp.d/98-chuwi-radios.conf

echo ">>> Подсказка в /etc/tlp.d/97-chuwi-readme.conf …"
cat >/etc/tlp.d/97-chuwi-readme.conf <<EOF
# Chuwi CoreBook X — профили режимов
# Активный набор параметров пишется скриптом:
#   ${TARGET_HOME}/power-mode.sh
# в файл /etc/tlp.d/99-chuwi-active-mode.conf (не править вручную).
EOF
chmod 0644 /etc/tlp.d/97-chuwi-readme.conf

echo ">>> Установка power-mode.sh в ${TARGET_HOME}/power-mode.sh …"
install -o "$TARGET_USER" -g "$TARGET_USER" -m 0755 "$SCRIPT_DIR/config/power-mode.sh" "${TARGET_HOME}/power-mode.sh"

echo ">>> Установка GUI-запуска TLP в /usr/local/bin (zenity + sudo -A, без терминала) …"
install -m 0755 "$SCRIPT_DIR/config/chuwi-askpass" /usr/local/bin/chuwi-askpass
install -m 0755 "$SCRIPT_DIR/config/chuwi-tlp-runner.sh" /usr/local/bin/chuwi-tlp-runner
install -m 0755 "$SCRIPT_DIR/config/chuwi-tlp-notify-root.sh" /usr/local/bin/chuwi-tlp-notify-root
rm -f /usr/local/bin/chuwi-tlp-notify "${TARGET_HOME}/power-mode-notify.sh"

echo ">>> Ярлыки в ${TARGET_HOME}/.local/share/applications/ …"
install -d -o "$TARGET_USER" -g "$TARGET_USER" -m 0755 "${TARGET_HOME}/.local/share/applications"
for src in "$SCRIPT_DIR"/config/desktop/*.desktop; do
  [[ -f "$src" ]] || continue
  base=$(basename "$src")
  install -o "$TARGET_USER" -g "$TARGET_USER" -m 0644 "$src" "${TARGET_HOME}/.local/share/applications/${base}"
done

if command -v update-desktop-database >/dev/null 2>&1; then
  sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" XDG_DATA_HOME="${TARGET_HOME}/.local/share" \
    update-desktop-database "${TARGET_HOME}/.local/share/applications" 2>/dev/null || true
fi

echo ">>> Перезапуск TLP …"
systemctl restart tlp.service 2>/dev/null || true

echo ""
echo "Готово."
echo "  Пользователь: $TARGET_USER"
echo "  Скрипт режимов:  ${TARGET_HOME}/power-mode.sh {eco|balanced|performance|reset}"
echo "  GUI-обёртка:     /usr/local/bin/chuwi-tlp-runner (ярлыки tlp-*.desktop)"
echo "  Ярлыки:          ${TARGET_HOME}/.local/share/applications/tlp-*.desktop"
echo "  TLP:             systemctl status tlp"
echo "  Проверка:        sudo tlp-stat -s   и   sudo tlp-stat -p"
echo ""
echo "Если в «Параметры → Питание» пропал слайдер режимов — это ожидаемо: его даёт power-profiles-daemon."
echo "Режимы переключайте ярлыками или командой выше."
echo ""
echo "Рекомендуется сразу применить комфортный режим (все ядра, яркость 100%):"
echo "  sudo ${TARGET_HOME}/power-mode.sh performance"
