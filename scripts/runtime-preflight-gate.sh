#!/usr/bin/env bash
set -euo pipefail

RUNNER_ID="${RUNNER_ID:-06}"
PROFILE_ID="${PROFILE_ID:-}"
ENV_SOURCE="${ENV_SOURCE:-/home/ramos/Документы/miniapp/backend/.env}"
EXPECTED_ENV_SOURCE="${EXPECTED_ENV_SOURCE:-/home/ramos/Документы/miniapp/backend/.env}"
COMPOSE_FILE="${COMPOSE_FILE:-/home/ramos/Документы/miniapp/docker-compose.yml}"
EXPECTED_DATABASE_URL="${EXPECTED_DATABASE_URL:-}"
CONTEXT_LABEL="${CONTEXT_LABEL:-runner}"
TS_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

fail() {
  local reason="$1"
  local hop="${2:-preflight}"
  echo "status=FAIL"
  echo "failure_hop=${hop}"
  echo "error=${reason}"
  exit 1
}

if [[ -z "${PROFILE_ID}" ]]; then
  fail "PROFILE_ID is required for deterministic preflight gate"
fi

if [[ ! -f "${ENV_SOURCE}" ]]; then
  fail "env source missing: ${ENV_SOURCE}" "env_source"
fi

if [[ "${ENV_SOURCE}" != "${EXPECTED_ENV_SOURCE}" ]]; then
  fail "env source mismatch: actual=${ENV_SOURCE} expected=${EXPECTED_ENV_SOURCE}" "env_source"
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  fail "compose file missing: ${COMPOSE_FILE}" "runtime"
fi

set -a
source "${ENV_SOURCE}"
set +a

DB_PROFILE_ACTUAL="${DB_RUNTIME_PROFILE_ID:-}"
DATABASE_URL_ACTUAL="${DATABASE_URL:-}"

if [[ -z "${DB_PROFILE_ACTUAL}" ]]; then
  fail "DB_RUNTIME_PROFILE_ID missing in env source ${ENV_SOURCE}" "profile"
fi

if [[ "${DB_PROFILE_ACTUAL}" != "${PROFILE_ID}" ]]; then
  fail "profile mismatch: actual=${DB_PROFILE_ACTUAL} expected=${PROFILE_ID}" "profile"
fi

if [[ -z "${DATABASE_URL_ACTUAL}" ]]; then
  fail "DATABASE_URL missing in env source ${ENV_SOURCE}" "profile"
fi

if [[ -n "${EXPECTED_DATABASE_URL}" && "${DATABASE_URL_ACTUAL}" != "${EXPECTED_DATABASE_URL}" ]]; then
  fail "DATABASE_URL mismatch against expected canonical DSN" "profile"
fi

DSN_REDACTED="$(echo "${DATABASE_URL_ACTUAL}" | sed -E 's#://([^:]+):[^@]+@#://\1:***@#')"

echo "status=START"
echo "context=${CONTEXT_LABEL}"
echo "runner_id=${RUNNER_ID}"
echo "utc=${TS_UTC}"
echo "profile_id=${DB_PROFILE_ACTUAL}"
echo "env_source=${ENV_SOURCE}"
echo "dsn_redacted=${DSN_REDACTED}"

echo "step=docker_info"
docker info >/dev/null
echo "step=docker_info status=PASS"

echo "step=compose_up_postgres"
docker compose -f "${COMPOSE_FILE}" up -d postgres >/dev/null
echo "step=compose_up_postgres status=PASS"

echo "step=postgres_ready_wait"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if docker compose -f "${COMPOSE_FILE}" exec -T postgres \
    pg_isready -U miniapp -d miniapp >/dev/null 2>&1; then
    echo "postgres_ready_attempt_${i}=PASS"
    break
  fi
  if [[ "${i}" -eq 10 ]]; then
    fail "postgres readiness timeout after compose up" "db_connect"
  fi
  sleep 1
done
echo "step=postgres_ready_wait status=PASS"

echo "step=tcp_check_3_of_3"
for i in 1 2 3; do
  if timeout 2 bash -lc "</dev/tcp/localhost/5432" >/dev/null 2>&1; then
    echo "tcp_pass_${i}"
  else
    fail "tcp localhost:5432 failed at attempt ${i}" "tcp"
  fi
done
echo "step=tcp_check_3_of_3 status=PASS"

echo "step=select_1"
SQL_OUT_FILE="/tmp/runner06-first-sql-success.log"
docker compose -f "${COMPOSE_FILE}" exec -T postgres \
  psql -h localhost -U miniapp -d miniapp -c "SELECT 1;" >"${SQL_OUT_FILE}"
echo "step=select_1 status=PASS"
echo "unlock_signal=${SQL_OUT_FILE}"

echo "status=PASS"
