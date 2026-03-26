#!/usr/bin/env bash
# Список установленных пакетов (имя, версия, архитектура).
set -euo pipefail
out="${1:-$HOME/Загрузки/installed-packages-$(date +%Y%m%d).txt}"
mkdir -p "$(dirname "$out")"
dpkg-query -W -f '${Package}\t${Version}\t${Architecture}\n' | sort -u >"$out"
echo "Записано $(wc -l <"$out") строк в $out"
