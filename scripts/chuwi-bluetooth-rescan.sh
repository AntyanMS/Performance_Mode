#!/usr/bin/env bash
# Сброс поиска Bluetooth: перезапуск bluetoothd, снятие фильтра D-Bus, длинный скан.
# Полезно, когда в GNOME «не видно новых» или bluetoothctl пишет Failed to stop discovery.
#
# Опции окружения (необязательно):
#   CHUWI_BT_WIFI_OFF=1  — на время скана выключить Wi‑Fi (тест совместности 2.4 ГГц с RTL8852).
#   CHUWI_BT_SCAN_SEC=N  — длительность скана в секундах (по умолчанию 25).
set -euo pipefail

if [[ "${EUID:-0}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

SCAN_SEC="${CHUWI_BT_SCAN_SEC:-25}"
WIFI_WAS_ON=0

restore_wifi() {
  if [[ "$WIFI_WAS_ON" == "1" ]]; then
    nmcli radio wifi on 2>/dev/null || true
    echo ">>> Wi‑Fi снова включён."
  fi
}

if [[ "${CHUWI_BT_WIFI_OFF:-0}" == "1" ]]; then
  trap restore_wifi EXIT
  if nmcli -t -f WIFI g 2>/dev/null | grep -q '^enabled$'; then
    WIFI_WAS_ON=1
  fi
  echo ">>> На время скана отключаю Wi‑Fi (CHUWI_BT_WIFI_OFF=1) …"
  nmcli radio wifi off
  sleep 2
fi

HCI_PATH="/org/bluez/hci0"

echo ">>> Останавливаю предыдущий поиск (ошибки можно игнорировать) …"
gdbus call --system -d org.bluez -o "$HCI_PATH" -m org.bluez.Adapter1.StopDiscovery >/dev/null 2>&1 || true
sleep 1

echo ">>> Перезапуск bluetooth.service …"
systemctl restart bluetooth.service
sleep 2

if gdbus introspect --system -d org.bluez -o "$HCI_PATH" &>/dev/null; then
  echo ">>> Сброс SetDiscoveryFilter (пустой фильтр) …"
  gdbus call --system -d org.bluez -o "$HCI_PATH" \
    -m org.bluez.Adapter1.SetDiscoveryFilter '{}' >/dev/null || true
else
  echo "!!! Адаптер $HCI_PATH не найден — проверьте rfkill и USB."
  exit 1
fi

cat <<'TIP'

>>> Перед сканом: на телефоне/наушниках включите ВИДИМОСТЬ или РЕЖИМ СОПРЯЖЕНИЯ
    (просто «Bluetooth вкл» часто НЕ достаточно — устройство не рекламируется).
    Закройте окно «Параметры → Bluetooth» в GNOME, пока идёт скан ниже.

TIP

echo ">>> Сканирование ${SCAN_SEC} с …"
timeout "$((SCAN_SEC + 3))" bluetoothctl --timeout "$SCAN_SEC" scan on 2>&1 || true
echo ""
echo ">>> Устройства, известные адаптеру:"
bluetoothctl devices

if [[ "${CHUWI_BT_WIFI_OFF:-0}" == "1" ]]; then
  restore_wifi
  trap - EXIT
fi

cat <<'NOTE'

Если по-прежнему только старые записи:
  • Удалите «залипшую» пару:  bluetoothctl remove AA:BB:CC:DD:EE:FF
  • После правок modprobe (btusb) нужен перезапуск модуля или перезагрузка:
      sudo modprobe -r btusb && sudo modprobe btusb && sudo systemctl restart bluetooth
  • Проверка «железа»: видит ли то же устройство Windows на этом ноуте.

NOTE
