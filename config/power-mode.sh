#!/bin/bash
# Три профиля питания (TLP + яркость). Wi‑Fi/Bluetooth остаются включёнными.
# Требуется sudo. Вентилятор: на этой модели нет ACPI platform_profile — кривая EC недоступна из Linux.

set -euo pipefail

MODE=${1:-}

BACKLIGHT=$(echo /sys/class/backlight/*/brightness 2>/dev/null | awk '{print $1}')
BACKLIGHT_MAX="${BACKLIGHT%/brightness}/max_brightness"

set_brightness_pct() {
    local pct=$1
    if [[ ! -f "$BACKLIGHT_MAX" || ! -f "$BACKLIGHT" ]]; then
        echo "Яркость: backlight не найден, пропуск"
        return 0
    fi
    local max val
    max=$(cat "$BACKLIGHT_MAX")
    val=$((max * pct / 100))
    [[ "$val" -lt 1 ]] && val=1
    [[ "$val" -gt "$max" ]] && val=$max
    echo "$val" | sudo tee "$BACKLIGHT" >/dev/null
    echo "Яркость: ~${pct}% ($val / $max)"
}

apply_tlp_snippet() {
    sudo tee /etc/tlp.d/99-chuwi-active-mode.conf >/dev/null
}

cpus_online_all() {
    local f n dir nums=()
    for f in /sys/devices/system/cpu/cpu*/online; do
        [[ -f "$f" ]] || continue
        dir=$(dirname "$f")
        n=$(basename "$dir")
        n=${n#cpu}
        [[ "$n" =~ ^[0-9]+$ ]] || continue
        nums+=("$n")
    done
    local sorted
    mapfile -t sorted < <(printf '%s\n' "${nums[@]}" | sort -n)
    for n in "${sorted[@]}"; do
        echo 1 | sudo tee "/sys/devices/system/cpu/cpu${n}/online" >/dev/null || true
    done
}

cpus_keep_first_two_only() {
    local f n dir nums=()
    for f in /sys/devices/system/cpu/cpu*/online; do
        [[ -f "$f" ]] || continue
        dir=$(dirname "$f")
        n=$(basename "$dir")
        n=${n#cpu}
        [[ "$n" =~ ^[0-9]+$ ]] || continue
        (( n >= 2 )) && nums+=("$n")
    done
    local sorted
    mapfile -t sorted < <(printf '%s\n' "${nums[@]}" | sort -nr)
    for n in "${sorted[@]}"; do
        echo 0 | sudo tee "/sys/devices/system/cpu/cpu${n}/online" >/dev/null || true
    done
    echo "CPU: онлайн только cpu0 и cpu1 (остальные отключены через hotplug)"
}

cpus_keep_half_threads() {
    local total target_keep f n dir nums_off=()
    total=$(nproc)
    target_keep=$((total / 2))
    (( target_keep < 1 )) && target_keep=1
    for f in /sys/devices/system/cpu/cpu*/online; do
        [[ -f "$f" ]] || continue
        dir=$(dirname "$f")
        n=$(basename "$dir")
        n=${n#cpu}
        [[ "$n" =~ ^[0-9]+$ ]] || continue
        (( n >= target_keep )) && nums_off+=("$n")
    done
    local sorted
    mapfile -t sorted < <(printf '%s\n' "${nums_off[@]}" | sort -nr)
    for n in "${sorted[@]}"; do
        echo 0 | sudo tee "/sys/devices/system/cpu/cpu${n}/online" >/dev/null || true
    done
    echo "CPU: онлайн ${target_keep} из ${total} потоков (первая половина)"
}

case "$MODE" in
  eco|quiet|q)
    cpus_online_all
    set_brightness_pct 1
    apply_tlp_snippet <<'EOF'
# --- eco: максимум автономности (генерируется power-mode.sh) ---
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=power
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_MIN_PERF_ON_AC=0
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_AC=10
CPU_MAX_PERF_ON_BAT=8
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_AC=0
CPU_HWP_DYN_BOOST_ON_BAT=0
WIFI_PWR_ON_AC=on
WIFI_PWR_ON_BAT=on
PCIE_ASPM_ON_AC=powersupersave
PCIE_ASPM_ON_BAT=powersupersave
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
EOF
    echo "🔋 Режим ECO: низкий потолок P-state (см. CPU_MAX в файле), без turbo, 2 ядра, тёмный экран, агрессивный ASPM"
    ;;
  balanced|b)
    cpus_online_all
    set_brightness_pct 30
    apply_tlp_snippet <<'EOF'
# --- balanced: половина потоков, ~50% потолка частоты, яркость 30% ---
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
CPU_MIN_PERF_ON_AC=0
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_AC=36
CPU_MAX_PERF_ON_BAT=32
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersave
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
EOF
    echo "⚖️ Режим BALANCED: ½ потоков, потолок CPU ~36%/32% (AC/БАТ), яркость 30%"
    ;;
  performance|p)
    cpus_online_all
    set_brightness_pct 100
    apply_tlp_snippet <<'EOF'
# --- performance: максимум из доступного в ОС ---
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=performance
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=performance
CPU_MIN_PERF_ON_AC=0
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_AC=100
CPU_MAX_PERF_ON_BAT=100
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=1
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=off
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=default
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=on
EOF
    echo "🚀 Режим PERFORMANCE: 100% CPU, turbo, яркость макс (вентилятор — прошивка EC)"
    ;;
  reset|r)
    sudo tlp start
    echo "♻️ Повторно применён текущий профиль из /etc/tlp.d/99-chuwi-active-mode.conf"
    ;;
  *)
    echo "Использование: $0 {eco|balanced|performance|reset}"
    echo "Коротко: $0 {e|q|b|p|r}   (quiet=q то же что eco)"
    exit 1
    ;;
esac

if [[ "$MODE" != "reset" && "$MODE" != "r" ]]; then
  sudo tlp start
fi

if [[ "$MODE" == "eco" || "$MODE" == "quiet" || "$MODE" == "q" ]]; then
  cpus_keep_first_two_only
elif [[ "$MODE" == "balanced" || "$MODE" == "b" ]]; then
  cpus_keep_half_threads
fi

echo "---"
bat_dev=$(upower -e 2>/dev/null | grep -m1 BAT || true)
if [[ -n "$bat_dev" ]]; then
  upower -i "$bat_dev" 2>/dev/null | grep -E 'state|percentage|energy-rate' || true
fi
sudo tlp-stat -s 2>/dev/null | grep -E 'Power source|Mode'
echo -n "Губернатор cpu0: "
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo -n "EPP cpu0: "
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo "(нет)"
sudo tlp-stat -p 2>/dev/null | grep -E 'scaling_governor|energy_performance_preference|boost|amd_pstate' | head -25 || true
echo -n "Онлайн логических CPU: "
grep -c '^processor' /proc/cpuinfo 2>/dev/null || true
echo "(ожидается: performance=все, balanced≈половина, eco=2)"
