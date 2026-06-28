#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOLLA_VENV_PATH="${KOLLA_VENV_PATH:-/root/kolla-venv}"
MULTINODE_PATH="${MULTINODE_PATH:-/root/multinode}"
LOG_DIR="${LOG_DIR:-/root/logs}"

usage() {
  cat <<'EOF'
Usage:
  ./kolla-run.sh <action> [kolla-ansible args...]

Actions:
  bootstrap-servers | prechecks | pull | certificates | octavia-certificates
  deploy | deploy-containers | post-deploy | reconfigure | stop | upgrade

Examples:
  ./kolla-run.sh prechecks
  ./kolla-run.sh reconfigure --tags cinder
  ./kolla-run.sh deploy --limit stack1
EOF
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "missing file: ${path}" >&2
    exit 1
  fi
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

ACTION="$1"
shift

case "${ACTION}" in
  bootstrap-servers|prechecks|pull|certificates|octavia-certificates|deploy|deploy-containers|post-deploy|reconfigure|stop|upgrade) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "unsupported action: ${ACTION}" >&2
    usage
    exit 1
    ;;
esac

require_file "${KOLLA_VENV_PATH}/bin/activate"
require_file "${MULTINODE_PATH}"

mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/kolla-${ACTION}-${TIMESTAMP}.log"

source "${KOLLA_VENV_PATH}/bin/activate"

echo "[INFO] host: $(hostname -s)"
echo "[INFO] action: ${ACTION}"
echo "[INFO] inventory: ${MULTINODE_PATH}"
echo "[INFO] log: ${LOG_FILE}"

stdbuf -oL kolla-ansible "${ACTION}" -i "${MULTINODE_PATH}" "$@" 2>&1 | tee "${LOG_FILE}"
status=${PIPESTATUS[0]}
if [[ ${status} -ne 0 ]]; then
  echo "[ERROR] kolla-ansible ${ACTION} failed with status ${status}" >&2
  exit "${status}"
fi

echo "[INFO] completed: ${ACTION}"
