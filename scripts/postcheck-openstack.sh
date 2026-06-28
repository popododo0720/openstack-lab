#!/usr/bin/env bash
set -euo pipefail

failures=0

run_check() {
  local title="$1"
  shift
  echo
  echo "== ${title} =="
  if ! bash -lc "$*"; then
    failures=$((failures + 1))
    echo "[FAIL] ${title}" >&2
  fi
}

if [[ -f /root/kolla-venv/bin/activate ]]; then
  source /root/kolla-venv/bin/activate
else
  echo "missing /root/kolla-venv/bin/activate" >&2
  exit 1
fi

openrc_found=0
for openrc in \
  /etc/kolla/admin-openrc.sh \
  /etc/kolla/admin-openrc-system.sh \
  /root/admin-openrc.sh \
  /root/admin-openrc-system.sh; do
  if [[ -f "${openrc}" ]]; then
    source "${openrc}"
    openrc_found=1
    break
  fi
done

if [[ ${openrc_found} -ne 1 ]]; then
  echo "missing admin-openrc file" >&2
  exit 1
fi

echo "host: $(hostname -s)"
echo "date: $(date -Is)"

run_check "Ceph" 'ceph -s'
run_check "Endpoints" 'openstack endpoint list -c "Service Name" -c Interface -c URL -f table'
run_check "Hypervisors" 'openstack hypervisor list -f table'
run_check "Compute Services" 'openstack compute service list -f table'
run_check "Network Agents" 'openstack network agent list -f table'
run_check "Volume Services" 'openstack volume service list -f table'
run_check "Volume Types" 'openstack volume type list -f table'
run_check "Images" 'openstack image list -f table'
run_check "Core Containers" "docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'keystone|glance|nova_|neutron_|cinder_|rabbitmq|mariadb|haproxy|ovn_'"

if [[ ${failures} -ne 0 ]]; then
  echo
  echo "[ERROR] postcheck failed: ${failures} check(s)" >&2
  exit 1
fi

echo
echo "[INFO] postcheck completed successfully"
