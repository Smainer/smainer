#!/usr/bin/env bash

set -u

PROJECT_ROOT="${PROJECT_ROOT:-/home/smainer/Smainer}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARTIFACT_ROOT="${PROJECT_ROOT}/artifacts/launch-readiness"
ARTIFACT_DIR="${ARTIFACT_ROOT}/${TIMESTAMP}"
TASK_LOG_DIR="${ARTIFACT_DIR}/tasks"
ENDPOINT_DIR="${ARTIFACT_DIR}/endpoints"
SERVICE_DIR="${ARTIFACT_DIR}/services"
RAW_DIR="${ARTIFACT_DIR}/raw"

mkdir -p "${TASK_LOG_DIR}" "${ENDPOINT_DIR}" "${SERVICE_DIR}" "${RAW_DIR}"

TASKS_CSV="${ARTIFACT_DIR}/task-lifecycle.csv"
CHECKLIST_MD="${ARTIFACT_DIR}/launch-readiness-checklist.md"
SUMMARY_MD="${ARTIFACT_DIR}/go-no-go-summary.md"
RUN_LOG="${ARTIFACT_DIR}/run.log"

HARD_FAIL_COUNT=0
TOTAL_FAIL_COUNT=0

REQUIRED_SERVICES=(
  "smainer-relayer"
  "smainer-provider"
  "redis"
  "redis-server"
)

append_log() {
  local line="$1"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$line" | tee -a "${RUN_LOG}" >/dev/null
}

redact_stream() {
  sed -E \
    -e 's/(Authorization:[[:space:]]*)(Bearer|Basic)[[:space:]]+[^[:space:]]+/\1\2 <REDACTED>/Ig' \
    -e 's/(X-API-Key:[[:space:]]*)[^[:space:]]+/\1<REDACTED>/Ig' \
    -e 's/([A-Za-z0-9_]*(TOKEN|SECRET|API_KEY|PRIVATE_KEY|MNEMONIC|SEED)[A-Za-z0-9_]*[[:space:]]*[:=][[:space:]]*)("[^"]*"|\047[^\047]*\047|[^[:space:]]+)/\1<REDACTED>/Ig' \
    -e 's/(0x)[a-fA-F0-9]{64}/\1<REDACTED>/g' \
    -e 's/[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}/<REDACTED_JWT>/g'
}

safe_capture() {
  local command="$1"
  local output_file="$2"
  local raw_file
  raw_file="$(mktemp)"

  set +e
  bash -lc "${command}" >"${raw_file}" 2>&1
  local exit_code=$?
  set -e

  redact_stream <"${raw_file}" >"${output_file}"
  rm -f "${raw_file}"
  return ${exit_code}
}

write_headers() {
  cat >"${TASKS_CSV}" <<'EOF'
task_id,severity,status,started_utc,ended_utc,duration_seconds,artifact,description
EOF
}

record_task() {
  local task_id="$1"
  local severity="$2"
  local description="$3"
  local command="$4"

  local started_epoch ended_epoch duration status artifact started_iso ended_iso
  local artifact_file
  artifact_file="${TASK_LOG_DIR}/${task_id}.log"

  started_epoch="$(date +%s)"
  started_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  append_log "START ${task_id} (${severity}): ${description}"
  if safe_capture "${command}" "${artifact_file}"; then
    status="PASS"
  else
    status="FAIL"
    TOTAL_FAIL_COUNT=$((TOTAL_FAIL_COUNT + 1))
    if [[ "${severity}" == "hard" ]]; then
      HARD_FAIL_COUNT=$((HARD_FAIL_COUNT + 1))
    fi
  fi

  ended_epoch="$(date +%s)"
  ended_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  duration=$((ended_epoch - started_epoch))
  artifact="tasks/${task_id}.log"

  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "${task_id}" "${severity}" "${status}" "${started_iso}" "${ended_iso}" "${duration}" "${artifact}" "${description}" \
    >>"${TASKS_CSV}"

  append_log "END ${task_id}: ${status} (${duration}s)"
}

collect_service_snapshot() {
  append_log "Collecting service status snapshots"

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname)"
    echo "kernel=$(uname -r)"
    echo "cwd=$(pwd)"
  } >"${SERVICE_DIR}/system-context.txt"

  for svc in "${REQUIRED_SERVICES[@]}"; do
    local out_file
    out_file="${SERVICE_DIR}/${svc}.status.txt"

    {
      echo "service=${svc}"
      echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
        echo "installed=yes"
        echo "is_active=$(systemctl is-active "${svc}" 2>/dev/null || true)"
        echo "is_enabled=$(systemctl is-enabled "${svc}" 2>/dev/null || true)"
        systemctl show "${svc}" -p ActiveState -p SubState -p MainPID -p FragmentPath -p ExecMainStartTimestamp --no-page 2>/dev/null || true
      else
        echo "installed=no"
      fi
      echo
    } | redact_stream >"${out_file}"
  done

  ps -eo pid,ppid,user,%cpu,%mem,etime,args \
    | grep -Ei 'redis|relayer|provider|uvicorn|gunicorn|fastapi' \
    | grep -Ev 'grep -Ei' \
    | redact_stream >"${SERVICE_DIR}/process-snapshot.txt" || true
}

collect_endpoints() {
  append_log "Collecting endpoint evidence"

  safe_capture "curl -sS -m 8 -D - http://127.0.0.1:8000/api/v1/health" "${ENDPOINT_DIR}/relayer-health.http.txt" || true
  safe_capture "curl -sS -m 8 -D - http://127.0.0.1:8000/health" "${ENDPOINT_DIR}/relayer-generic-health.http.txt" || true

  if command -v sncast >/dev/null 2>&1; then
    safe_capture "cd '${PROJECT_ROOT}/contracts' && sncast call --contract-address 0x040f979da0daf49e1007eed2634e5d3acfd475bfffca03e771c1654a5721b212 --function get_relayer --network mainnet" "${ENDPOINT_DIR}/contract-get-relayer.txt" || true
  else
    echo "sncast not available" >"${ENDPOINT_DIR}/contract-get-relayer.txt"
  fi
}

write_checklist() {
  local decision
  local secret_scan relayer_health service_active contract_query backend_tests

  secret_scan="$(awk -F, '$1=="hard_secret_scan" {print $3}' "${TASKS_CSV}")"
  relayer_health="$(awk -F, '$1=="hard_relayer_health_200" {print $3}' "${TASKS_CSV}")"
  service_active="$(awk -F, '$1=="hard_required_service_active" {print $3}' "${TASKS_CSV}")"
  contract_query="$(awk -F, '$1=="hard_contract_relayer_query" {print $3}' "${TASKS_CSV}")"
  backend_tests="$(awk -F, '$1=="hard_backend_security_tests" {print $3}' "${TASKS_CSV}")"

  if [[ ${HARD_FAIL_COUNT} -eq 0 ]]; then
    decision="GO"
  else
    decision="NO-GO"
  fi

  cat >"${CHECKLIST_MD}" <<EOF
# Launch Readiness Checklist

- Timestamp (UTC): ${TIMESTAMP}
- Artifact directory: ${ARTIFACT_DIR}
- Decision: ${decision}

## Hard Gates
- [$( [[ "${secret_scan}" == "PASS" ]] && echo x || echo ' ' )] No hardcoded secrets detected by hard scan (${secret_scan})
- [$( [[ "${relayer_health}" == "PASS" ]] && echo x || echo ' ' )] Relayer health endpoint returns HTTP 200 (${relayer_health})
- [$( [[ "${service_active}" == "PASS" ]] && echo x || echo ' ' )] At least one required service is active (${service_active})
- [$( [[ "${contract_query}" == "PASS" ]] && echo x || echo ' ' )] Contract relayer query succeeds (${contract_query})
- [$( [[ "${backend_tests}" == "PASS" ]] && echo x || echo ' ' )] Backend security test script passes (${backend_tests})

## Evidence Pointers
- Task lifecycle: task-lifecycle.csv
- Service snapshots: services/
- Endpoint captures: endpoints/
- Per-task logs: tasks/
EOF
}

write_summary() {
  local decision hard_status
  if [[ ${HARD_FAIL_COUNT} -eq 0 ]]; then
    decision="GO"
    hard_status="All hard gates passed"
  else
    decision="NO-GO"
    hard_status="${HARD_FAIL_COUNT} hard gate(s) failed"
  fi

  cat >"${SUMMARY_MD}" <<EOF
# GO/NO-GO Summary

- Generated at (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Artifact directory: ${ARTIFACT_DIR}
- Decision: ${decision}
- Hard gate status: ${hard_status}
- Total failed checks: ${TOTAL_FAIL_COUNT}

## Hard Gate Results
EOF

  awk -F, 'NR>1 && $2=="hard" {printf "- %s: %s (%s)\n", $1, $3, $8}' "${TASKS_CSV}" >>"${SUMMARY_MD}"

  {
    echo
    echo "## Output Files"
    echo "- $(basename "${TASKS_CSV}")"
    echo "- $(basename "${CHECKLIST_MD}")"
    echo "- $(basename "${SUMMARY_MD}")"
  } >>"${SUMMARY_MD}"
}

main() {
  set -e

  append_log "Launch readiness evidence collection started"
  write_headers

  collect_service_snapshot
  collect_endpoints

  # Hard gates
  record_task "hard_secret_scan" "hard" "No hardcoded secrets detected by git grep" "cd '${PROJECT_ROOT}' && git grep -n -I -E '(private_key|PRIVATE_KEY|api_key|API_KEY|TOKEN|SECRET).*(0x[a-fA-F0-9]{64}|[A-Za-z0-9_\-]{20,})' -- ':!*.example' ':!*.template' ':!**/node_modules/**' ':!**/target/**' >/dev/null && exit 1 || exit 0"
  record_task "hard_relayer_health_200" "hard" "Relayer health endpoint returns HTTP 200" "curl -sS -m 8 -o '${RAW_DIR}/relayer-health.body' -w '%{http_code}' http://127.0.0.1:8000/api/v1/health | grep -q '^200$'"
  record_task "hard_required_service_active" "hard" "Relayer/provider/redis service active" "systemctl is-active smainer-relayer smainer-provider redis redis-server 2>/dev/null | grep -Eq 'active'"
  record_task "hard_contract_relayer_query" "hard" "Contract get_relayer query succeeds" "command -v sncast >/dev/null 2>&1 && cd '${PROJECT_ROOT}/contracts' && sncast call --contract-address 0x040f979da0daf49e1007eed2634e5d3acfd475bfffca03e771c1654a5721b212 --function get_relayer --network mainnet >/dev/null"
  record_task "hard_backend_security_tests" "hard" "Backend security tests pass" "cd '${PROJECT_ROOT}' && ./backend/run-security-tests.sh"

  # Soft gates
  record_task "soft_quick_security" "soft" "Quick security check script" "cd '${PROJECT_ROOT}' && ./quick-security-check.sh"
  record_task "soft_war_room_gates" "soft" "War room security gates" "cd '${PROJECT_ROOT}' && ./war-room-security-gates.sh"

  # Redact any collected raw endpoint body after status check use.
  if [[ -f "${RAW_DIR}/relayer-health.body" ]]; then
    redact_stream <"${RAW_DIR}/relayer-health.body" >"${ENDPOINT_DIR}/relayer-health.body.txt"
    rm -f "${RAW_DIR}/relayer-health.body"
  fi

  write_checklist
  write_summary

  append_log "Launch readiness evidence collection complete"
  echo "Artifacts written to: ${ARTIFACT_DIR}"

  if [[ ${HARD_FAIL_COUNT} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
