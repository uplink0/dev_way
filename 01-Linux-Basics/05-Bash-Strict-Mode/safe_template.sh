#!/usr/bin/env bash
# ==============================================================================
# Production-ready Bash Script Template
# ==============================================================================
# Строгий режим:
set -euo pipefail
# Константы окружения:
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TMP_DIR=$(mktemp -d)
# Ловушка (Trap): гарантированная очистка временных файлов при любом выходе/сбое:
cleanup() {
    local exit_code=$?
    rm -rf "${TMP_DIR}"
    if [ "${exit_code}" -ne 0 ]; then
        echo "[ERROR] Скрипт завершился с ошибкой (код: ${exit_code})" >&2
    fi
}
trap cleanup EXIT INT TERM
echo "[INFO] Скрипт запущен из: ${SCRIPT_DIR}"
echo "[INFO] Временная директория: ${TMP_DIR}"
echo "[INFO] Всё отработало успешно!"
