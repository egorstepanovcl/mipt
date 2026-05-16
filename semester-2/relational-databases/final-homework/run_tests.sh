#!/usr/bin/env bash
# Запуск тестов базы данных.
# Использование:
#   ./run_tests.sh              — все тесты по порядку
#   ./run_tests.sh test_stage_1 — только один файл (без .sql)

set -euo pipefail

CONTAINER="db"
DB_USER="postgres"
DB_NAME="postgres"
TESTS_DIR="./tests"

run_file() {
    local file="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Running: $(basename "$file")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    docker compose exec -T "$CONTAINER" \
        psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "/tests/$(basename "$file")"
}

if [ $# -eq 1 ]; then
    # Запуск конкретного файла
    run_file "${TESTS_DIR}/${1}.sql"
else
    # Запуск всех файлов в алфавитном порядке
    for f in $(ls "${TESTS_DIR}"/test_stage_*.sql 2>/dev/null | sort); do
        run_file "$f"
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ALL TESTS COMPLETED SUCCESSFULLY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
