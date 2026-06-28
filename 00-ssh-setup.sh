#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/inventory.ini"
ROOT_PASS="root"

HOSTS=()
PORTS=()
NAMES=()
MANAGEMENT_IPS=()
STORAGE_IPS=()
INTERNAL_IPS=()
TUNNEL_IPS=()
EXTERNAL_IPS=()

extract_value() {
    local key="$1"
    local line="$2"
    echo "$line" | tr ' ' '\n' | awk -F= -v k="$key" '$1 == k {print $2}'
}

extract_cidr_suffix() {
    local key="$1"
    local value
    value=$(awk -F= -v k="$key" '$1 == k {print $2}' "$INVENTORY_FILE")
    if [ -n "$value" ] && [[ "$value" == */* ]]; then
        echo "/${value##*/}"
    else
        echo "/24"
    fi
}

inventory_get() {
    local key="$1"
    awk -F= -v k="$key" '$1 == k {print $2}' "$INVENTORY_FILE" | tail -n 1
}

inventory_get_required() {
    local key="$1"
    local value
    value="$(inventory_get "$key")"
    if [ -z "$value" ]; then
        echo "inventory.ini 에 $key 값이 없습니다." >&2
        exit 1
    fi
    echo "$value"
}

yaml_flow_list_from_words() {
    local raw="$1"
    local out="["
    local first=1
    for item in $raw; do
        if [ $first -eq 0 ]; then
            out+=", "
        fi
        out+="$item"
        first=0
    done
    out+="]"
    echo "$out"
}

yaml_flow_list_from_csv() {
    local raw="$1"
    yaml_flow_list_from_words "$(echo "$raw" | tr ',' ' ')"
}

ssh_port_opt() {
    local port="$1"
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        printf '%s\n' "-p $port"
    fi
}

ssh_target() {
    local host="$1"
    local port="$2"
    printf '%s\n' "root@$host"
}

first_csv_item() {
    local raw="$1"
    echo "${raw%%,*}" | awk '{$1=$1; print}'
}

bond_mode_or_default() {
    local mode="$1"
    if [ -n "$mode" ]; then
        echo "$mode"
    else
        echo "active-backup"
    fi
}

append_netplan_ethernet_slave() {
    local ifname="$1"
    [ -n "$ifname" ] || return 0
    if [ -n "${ADDED_ETHERNETS[$ifname]+x}" ]; then
        return 0
    fi
    ADDED_ETHERNETS[$ifname]=1
    netplan_ethernet_block+=$(cat <<EOF
    ${ifname}:
      dhcp4: false
      dhcp6: false
EOF
)
    netplan_ethernet_block+=$'\n'
}

append_netplan_physical_role() {
    local ifname="$1"
    local ip_addr="$2"
    local cidr="$3"
    local default_route="$4"
    local dns_servers="$5"

    append_netplan_ethernet_slave "$ifname"
    if [ -n "$ip_addr" ]; then
        netplan_ethernet_block+=$(cat <<EOF
      addresses:
        - ${ip_addr}${cidr}
EOF
)
        netplan_ethernet_block+=$'\n'
    fi
    if [ "$default_route" = "yes" ]; then
        netplan_ethernet_block+=$(cat <<EOF
      routes:
        - to: default
          via: ${EXTERNAL_GATEWAY}
EOF
)
        netplan_ethernet_block+=$'\n'
    fi
    if [ -n "$dns_servers" ]; then
        netplan_ethernet_block+=$(cat <<EOF
      nameservers:
        addresses: ${dns_servers}
EOF
)
        netplan_ethernet_block+=$'\n'
    fi
}

append_netplan_bond_role() {
    local bond_name="$1"
    local bond_interfaces="$2"
    local primary_if="$3"
    local mode="$4"
    local ip_addr="$5"
    local cidr="$6"
    local default_route="$7"
    local dns_servers="$8"

    IFS=',' read -r -a bond_ifs <<< "$bond_interfaces"
    for bond_if in "${bond_ifs[@]}"; do
        append_netplan_ethernet_slave "$bond_if"
    done

    if [ -z "$primary_if" ]; then
        primary_if="$(first_csv_item "$bond_interfaces")"
    fi
    mode="$(bond_mode_or_default "$mode")"

    netplan_bond_block+=$(cat <<EOF
    ${bond_name}:
      interfaces: $(yaml_flow_list_from_csv "$bond_interfaces")
EOF
)
    netplan_bond_block+=$'\n' 
    if [ -n "$ip_addr" ]; then
        netplan_bond_block+=$(cat <<EOF
      addresses:
        - ${ip_addr}${cidr}
EOF
)
        netplan_bond_block+=$'\n'
    fi
    if [ "$default_route" = "yes" ]; then
        netplan_bond_block+=$(cat <<EOF
      routes:
        - to: default
          via: ${EXTERNAL_GATEWAY}
EOF
)
        netplan_bond_block+=$'\n'
    fi
    if [ -n "$dns_servers" ]; then
        netplan_bond_block+=$(cat <<EOF
      nameservers:
        addresses: ${dns_servers}
EOF
)
        netplan_bond_block+=$'\n'
    fi
    netplan_bond_block+=$(cat <<EOF
      parameters:
        mode: ${mode}
        primary: ${primary_if}
        mii-monitor-interval: 100
EOF
)
    netplan_bond_block+=$'\n'
}

append_netplan_role() {
    local ifname="$1"
    local ip_addr="$2"
    local cidr="$3"
    local bond_interfaces="$4"
    local primary_if="$5"
    local mode="$6"
    local default_route="$7"
    local dns_servers="$8"

    if [ -n "$bond_interfaces" ]; then
        append_netplan_bond_role "$ifname" "$bond_interfaces" "$primary_if" "$mode" "$ip_addr" "$cidr" "$default_route" "$dns_servers"
    else
        append_netplan_physical_role "$ifname" "$ip_addr" "$cidr" "$default_route" "$dns_servers"
    fi
}

while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# || "$line" =~ ^\[ ]] && continue
    [[ "$line" != stack* ]] && continue

    NAMES+=("$(echo "$line" | awk '{print $1}')")
    HOSTS+=("$(extract_value ansible_host "$line")")
    port="$(extract_value ansible_port "$line")"
    PORTS+=("${port:-22}")
    MANAGEMENT_IPS+=("$(extract_value ansible_host "$line")")
    STORAGE_IPS+=("$(extract_value storage_ip "$line")")
    INTERNAL_IPS+=("$(extract_value internal_ip "$line")")
    TUNNEL_IPS+=("$(extract_value tunnel_ip "$line")")
    EXTERNAL_IPS+=("$(extract_value external_ip "$line")")
done < "$INVENTORY_FILE"

MANAGEMENT_ENABLED="$(inventory_get management_enabled)"
if [ -z "$MANAGEMENT_ENABLED" ]; then
    MANAGEMENT_ENABLED="true"
fi
MANAGEMENT_IF="$(inventory_get management_interface)"
MANAGEMENT_BOND_INTERFACES="$(inventory_get management_bond_interfaces)"
MANAGEMENT_BOND_PRIMARY="$(inventory_get management_bond_primary)"
MANAGEMENT_BOND_MODE="$(inventory_get management_bond_mode)"
EXTERNAL_IF="$(inventory_get_required external_interface)"
EXTERNAL_BOND_INTERFACES="$(inventory_get external_bond_interfaces)"
EXTERNAL_BOND_PRIMARY="$(inventory_get external_bond_primary)"
EXTERNAL_BOND_MODE="$(inventory_get external_bond_mode)"
NEUTRON_EXTERNAL_IF="$(inventory_get_required neutron_external_interface)"
NEUTRON_EXTERNAL_BOND_INTERFACES="$(inventory_get neutron_external_bond_interfaces)"
NEUTRON_EXTERNAL_BOND_PRIMARY="$(inventory_get neutron_external_bond_primary)"
NEUTRON_EXTERNAL_BOND_MODE="$(inventory_get neutron_external_bond_mode)"
TUNNEL_IF="$(inventory_get tunnel_interface)"
TUNNEL_BOND_INTERFACES="$(inventory_get tunnel_bond_interfaces)"
TUNNEL_BOND_PRIMARY="$(inventory_get tunnel_bond_primary)"
TUNNEL_BOND_MODE="$(inventory_get tunnel_bond_mode)"
INTERNAL_IF="$(inventory_get_required network_interface)"
INTERNAL_BOND_INTERFACES="$(inventory_get internal_bond_interfaces)"
INTERNAL_BOND_PRIMARY="$(inventory_get internal_bond_primary)"
INTERNAL_BOND_MODE="$(inventory_get internal_bond_mode)"
STORAGE_IF="$(inventory_get_required storage_interface)"
STORAGE_BOND_INTERFACES="$(inventory_get storage_bond_interfaces)"
STORAGE_BOND_PRIMARY="$(inventory_get storage_bond_primary)"
STORAGE_BOND_MODE="$(inventory_get storage_bond_mode)"
EXTERNAL_GATEWAY="$(inventory_get external_gateway)"
if [ -z "$EXTERNAL_GATEWAY" ]; then
    EXTERNAL_GATEWAY="$(awk -F= '$1 == "external_network" {split($2, a, "."); print a[1] "." a[2] "." a[3] ".1"}' "$INVENTORY_FILE")"
fi
DNS_SERVERS="$(yaml_flow_list_from_words "$(inventory_get_required site_dns_servers)")"

MANAGEMENT_CIDR="$(extract_cidr_suffix management_network)"
STORAGE_CIDR="$(extract_cidr_suffix storage_network)"
INTERNAL_CIDR="$(extract_cidr_suffix internal_network)"
TUNNEL_CIDR="$(extract_cidr_suffix tunnel_network)"
EXTERNAL_CIDR="$(extract_cidr_suffix external_network)"
TUNNEL_NETWORK="$(inventory_get tunnel_network)"

OSD_DEVICES_RAW="$(awk -F= '$1 == "osd_devices" {print $2}' "$INVENTORY_FILE")"
IFS=',' read -r -a OSD_DEVICES <<< "$OSD_DEVICES_RAW"

if [ ! -f /root/.ssh/id_rsa ]; then
    echo "[1/5] SSH 키 생성..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -q
else
    echo "[1/5] SSH 키 이미 존재"
fi

echo "[2/5] SSH 키 배포 (관리 네트워크)..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    port=${PORTS[$i]}
    name=${NAMES[$i]}
    ssh-keygen -f /root/.ssh/known_hosts -R "[$host]:$port" 2>/dev/null || true
    ssh-keygen -f /root/.ssh/known_hosts -R "$host" 2>/dev/null || true
    echo "  → $name ($host:$port)"
    sshpass -p "$ROOT_PASS" ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no $(ssh_port_opt "$port") root@"$host"
done

echo "[3/5] SSH 연결 테스트..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    port=${PORTS[$i]}
    name=${NAMES[$i]}
    result=$(ssh -o StrictHostKeyChecking=no $(ssh_port_opt "$port") root@"$host" "hostname" 2>/dev/null)
    if [ "$result" = "$name" ]; then
        echo "  ✓ $name ($host:$port) OK"
    else
        echo "  ✗ $name ($host:$port) FAILED"
        exit 1
    fi
done

echo "[4/5] OSD 디스크 초기화 (Ceph용)..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    port=${PORTS[$i]}
    name=${NAMES[$i]}
    for dev in "${OSD_DEVICES[@]}"; do
        echo "  → $name ($host:$port) $dev 초기화"
        ssh -o StrictHostKeyChecking=no $(ssh_port_opt "$port") root@"$host" "dmsetup remove_all 2>/dev/null; vgremove -f \$(vgs --noheadings -o vg_name 2>/dev/null | grep ceph) 2>/dev/null; wipefs -af $dev; sgdisk --zap-all $dev; dd if=/dev/zero of=$dev bs=1M count=100 2>/dev/null; partprobe $dev; echo done"
        echo "    OK"
    done
done

echo "[5/5] 운영 네트워크 netplan 설정..."
for i in "${!HOSTS[@]}"; do
    host=${HOSTS[$i]}
    port=${PORTS[$i]}
    name=${NAMES[$i]}
    management_ip=${MANAGEMENT_IPS[$i]}
    storage_ip=${STORAGE_IPS[$i]}
    internal_ip=${INTERNAL_IPS[$i]}
    tunnel_ip=${TUNNEL_IPS[$i]}
    external_ip=${EXTERNAL_IPS[$i]}
    netplan_ethernet_block=""
    netplan_bond_block=""
    netplan_bond_section=""
    declare -A ADDED_ETHERNETS=()

    if [ "$MANAGEMENT_ENABLED" != "false" ] && [ -n "$MANAGEMENT_IF" ]; then
        append_netplan_role "$MANAGEMENT_IF" "$management_ip" "$MANAGEMENT_CIDR" "$MANAGEMENT_BOND_INTERFACES" "$MANAGEMENT_BOND_PRIMARY" "$MANAGEMENT_BOND_MODE" "no" ""
    fi
    append_netplan_role "$EXTERNAL_IF" "$external_ip" "$EXTERNAL_CIDR" "$EXTERNAL_BOND_INTERFACES" "$EXTERNAL_BOND_PRIMARY" "$EXTERNAL_BOND_MODE" "yes" "$DNS_SERVERS"
    append_netplan_role "$NEUTRON_EXTERNAL_IF" "" "" "$NEUTRON_EXTERNAL_BOND_INTERFACES" "$NEUTRON_EXTERNAL_BOND_PRIMARY" "$NEUTRON_EXTERNAL_BOND_MODE" "no" ""
    append_netplan_role "$INTERNAL_IF" "$internal_ip" "$INTERNAL_CIDR" "$INTERNAL_BOND_INTERFACES" "$INTERNAL_BOND_PRIMARY" "$INTERNAL_BOND_MODE" "no" ""
    if [ -n "$TUNNEL_IF" ] && [ -n "$TUNNEL_NETWORK" ] && [ -n "$tunnel_ip" ] && [ "$TUNNEL_IF" != "$INTERNAL_IF" ]; then
        append_netplan_role "$TUNNEL_IF" "$tunnel_ip" "$TUNNEL_CIDR" "$TUNNEL_BOND_INTERFACES" "$TUNNEL_BOND_PRIMARY" "$TUNNEL_BOND_MODE" "no" ""
    fi
    append_netplan_role "$STORAGE_IF" "$storage_ip" "$STORAGE_CIDR" "$STORAGE_BOND_INTERFACES" "$STORAGE_BOND_PRIMARY" "$STORAGE_BOND_MODE" "no" ""

    if [ -n "$netplan_bond_block" ]; then
        netplan_bond_section=$(cat <<EOF
  bonds:
${netplan_bond_block}
EOF
)
    fi

    echo "  → $name ($host:$port) cloud-init netplan 덮어쓰기"
    ssh -o StrictHostKeyChecking=no $(ssh_port_opt "$port") root@"$host" "cat > /etc/netplan/50-cloud-init.yaml <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
${netplan_ethernet_block}
${netplan_bond_section}
NETPLAN
netplan generate
rm -f /tmp/fxhci-netplan-apply.log
nohup sh -c 'sleep 2; netplan apply > /tmp/fxhci-netplan-apply.log 2>&1' >/dev/null 2>&1 &"

    echo "    재접속 대기: $name ($host:$port)"
    ok=0
    for _ in $(seq 1 60); do
        sleep 2
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 $(ssh_port_opt "$port") root@"$host" "test \"\$(hostname)\" = \"$name\" && cat /tmp/fxhci-netplan-apply.log 2>/dev/null || true" >/tmp/fxhci-netplan-check.log 2>&1; then
            ok=1
            break
        fi
    done
    if [ "$ok" -ne 1 ]; then
        echo "  ✗ $name ($host:$port) netplan 적용 후 재접속 실패"
        cat /tmp/fxhci-netplan-check.log 2>/dev/null || true
        exit 1
    fi
    echo "    OK"
done

echo ""
echo "완료."
