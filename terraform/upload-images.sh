#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="${SCRIPT_DIR}/images"
INVENTORY_FILE="${SCRIPT_DIR}/../inventory.ini"
REMOTE_IMAGE_DIR="/root/terraform-images"

inventory_get() {
  local key="$1"
  awk -F= -v k="$key" '$1 == k {print $2}' "$INVENTORY_FILE" | tail -n 1
}

registry_host_from_inventory() {
  local registry
  registry="$(inventory_get local_registry)"
  if [ -z "$registry" ]; then
    echo "local_registry is missing in $INVENTORY_FILE" >&2
    exit 1
  fi
  printf '%s\n' "${registry%%:*}"
}

repo_base_url_from_inventory() {
  local explicit
  explicit="$(inventory_get terraform_repo_base_url)"
  if [ -z "$explicit" ]; then
    explicit="$(inventory_get repo_base_url)"
  fi
  if [ -n "$explicit" ]; then
    printf '%s\n' "$explicit"
    return
  fi
  printf 'https://%s\n' "$REPO_HOST"
}

REPO_HOST="${REPO_HOST:-$(registry_host_from_inventory)}"
REPO_BASE_URL="${REPO_BASE_URL:-$(repo_base_url_from_inventory)}"
NEXUS_RAW_BASE_URL="${NEXUS_RAW_BASE_URL:-${REPO_BASE_URL}/repository/raw-hosted}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-CHANGEME_PASSWORD}"

get_inventory_host() {
  local host_name="${1:-stack1}"
  awk -v host="$host_name" '
    /^\[/ { section=$0; next }
    section == "[all]" && $1 == host {
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^ansible_host=/) {
          split($i, parts, "=")
          print parts[2]
          exit
        }
      }
      print $1
      exit
    }
  ' "$INVENTORY_FILE"
}

STACK1_HOST="${STACK1_HOST:-$(get_inventory_host stack1)}"
if [ -z "$STACK1_HOST" ]; then
  echo "failed to resolve stack1 ansible_host from $INVENTORY_FILE" >&2
  exit 1
fi
REMOTE_HOST="${REMOTE_HOST:-root@${STACK1_HOST}}"
SSH_OPTS=(-o StrictHostKeyChecking=no)
SCP_OPTS=(-o StrictHostKeyChecking=no)

ensure_remote_image_dir() {
  ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "mkdir -p '$REMOTE_IMAGE_DIR'"
}

ensure_local_file() {
  local filename="$1"
  local target="${IMAGE_DIR}/${filename}"
  local partial="${target}.part"
  local url="${NEXUS_RAW_BASE_URL}/${filename}"

  mkdir -p "$IMAGE_DIR"
  if [ -s "$target" ]; then
    return 0
  fi

  echo "download: $filename"
  rm -f "$partial"
  curl -kfL --retry 3 --retry-delay 2     -u "${NEXUS_USER}:${NEXUS_PASSWORD}"     -o "$partial" "$url"
  mv "$partial" "$target"
}

sync_remote_file() {
  local filename="$1"
  local local_path="${IMAGE_DIR}/${filename}"
  local remote_path="${REMOTE_IMAGE_DIR}/${filename}"

  ensure_local_file "$filename"

  if [ ! -s "$local_path" ]; then
    echo "missing local image after download attempt: $local_path" >&2
    return 1
  fi

  local local_size remote_size
  local_size=$(stat -c %s "$local_path")
  remote_size=$(ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" "stat -c %s '$remote_path' 2>/dev/null || echo 0")

  if [ "$local_size" != "$remote_size" ]; then
    echo "sync: $filename"
    scp "${SCP_OPTS[@]}" "$local_path" "$REMOTE_HOST:$remote_path"
  else
    echo "remote-skip: $filename"
  fi
}

upload_image() {
  local image_name="$1"
  local filename="$2"
  local visibility="$3"
  local disk_format="$4"
  shift 4
  local props=("$@")
  local remote_path="${REMOTE_IMAGE_DIR}/${filename}"
  local props_file props_b64

  sync_remote_file "$filename"

  props_file=$(mktemp)
  printf '%s\n' "${props[@]}" > "$props_file"
  props_b64=$(base64 -w0 "$props_file")
  rm -f "$props_file"

  ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" \
    IMAGE_NAME="$image_name" \
    REMOTE_FILE="$remote_path" \
    VISIBILITY="$visibility" \
    DISK_FORMAT="$disk_format" \
    PROPS_B64="$props_b64" \
    'bash -s' <<'EOS'
set -euo pipefail

. /root/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh

if openstack image show "$IMAGE_NAME" >/dev/null 2>&1; then
  status=$(openstack image show "$IMAGE_NAME" -f value -c status || true)
  if [ "$status" = "active" ]; then
    echo "image-skip: $IMAGE_NAME (active)"
    exit 0
  fi

  echo "image-delete-stale: $IMAGE_NAME ($status)"
  openstack image delete "$IMAGE_NAME" || true
  sleep 2
fi

mapfile -t props < <(printf '%s' "$PROPS_B64" | base64 -d)
cmd=(openstack image create "$IMAGE_NAME" --disk-format "$DISK_FORMAT" --container-format bare "--$VISIBILITY" --file "$REMOTE_FILE")
for kv in "${props[@]}"; do
  [ -n "$kv" ] || continue
  case "$kv" in
    min_disk=*)
      cmd+=(--min-disk "${kv#min_disk=}")
      ;;
    min_ram=*)
      cmd+=(--min-ram "${kv#min_ram=}")
      ;;
    *)
      cmd+=(--property "$kv")
      ;;
  esac
done

echo "image-create: $IMAGE_NAME"
"${cmd[@]}" >/tmp/openstack-image-create-${IMAGE_NAME}.out

for _ in $(seq 1 180); do
  status=$(openstack image show "$IMAGE_NAME" -f value -c status 2>/dev/null || true)
  case "$status" in
    active)
      echo "image-active: $IMAGE_NAME"
      exit 0
      ;;
    queued|saving|uploading|importing)
      sleep 5
      ;;
    '')
      sleep 2
      ;;
    *)
      echo "image-failed: $IMAGE_NAME status=$status" >&2
      exit 1
      ;;
  esac
done

echo "image-timeout: $IMAGE_NAME status=${status:-unknown}" >&2
exit 1
EOS
}

ensure_remote_image_dir

upload_image "cirros-0.6.3" "cirros-0.6.3-x86_64-disk.img" public qcow2 \
  "os_type=linux" \
  "os_admin_user=cirros"

upload_image "ubuntu-24.04" "ubuntu-24.04-noble-amd64.img" public qcow2 \
  "os_type=linux" \
  "os_distro=ubuntu" \
  "os_version=24.04" \
  "os_admin_user=ubuntu"

upload_image "debian-12" "debian-12-bookworm-genericcloud-amd64.qcow2" public qcow2 \
  "os_type=linux" \
  "os_distro=debian" \
  "os_version=12" \
  "os_admin_user=debian"

upload_image "rocky-9" "rocky-9-genericcloud-base.qcow2" public qcow2 \
  "os_type=linux" \
  "os_distro=rocky" \
  "os_version=9" \
  "os_admin_user=rocky"

upload_image "centos-stream-9" "centos-stream-9-genericcloud.qcow2" public qcow2 \
  "os_type=linux" \
  "os_distro=centos" \
  "os_version=9-stream" \
  "os_admin_user=cloud-user"

upload_image "alpine-3.19.8" "alpine-3.19.8-nocloud-cloudinit.qcow2" public qcow2 \
  "os_type=linux" \
  "os_distro=alpine" \
  "os_version=3.19.8"

upload_image "vjailbreak-golden-v0.4.5-dhcp" "vjailbreak-golden-v0.4.5-dhcp.qcow2" public qcow2 \
  "os_type=linux" \
  "os_distro=ubuntu" \
  "os_version=22.04" \
  "os_admin_user=ubuntu" \
  "hw_disk_bus=virtio" \
  "hw_vif_model=virtio"

upload_image "windows-10-openstack" "windows-10-openstack.qcow2" public qcow2 \
  "min_disk=80" \
  "os_type=windows" \
  "os_distro=windows" \
  "os_version=10" \
  "os_admin_user=Administrator" \
  "architecture=x86_64" \
  "hw_firmware_type=uefi" \
  "hw_machine_type=q35" \
  "hw_disk_bus=virtio" \
  "hw_vif_model=virtio"

upload_image "windows-11-openstack" "windows-11-openstack.qcow2" public qcow2 \
  "min_disk=80" \
  "os_type=windows" \
  "os_distro=windows" \
  "os_version=11" \
  "os_admin_user=Administrator" \
  "architecture=x86_64" \
  "hw_firmware_type=uefi" \
  "hw_machine_type=q35" \
  "hw_disk_bus=virtio" \
  "hw_vif_model=virtio"

sync_remote_file "amphora-x64-haproxy.qcow2"
ssh "${SSH_OPTS[@]}" "$REMOTE_HOST" 'bash -s' <<'EOS'
set -euo pipefail

. /root/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh

IMAGE_NAME="amphora-x64-haproxy"
REMOTE_FILE="/root/terraform-images/amphora-x64-haproxy.qcow2"

if openstack image show "$IMAGE_NAME" >/dev/null 2>&1; then
  status=$(openstack image show "$IMAGE_NAME" -f value -c status || true)
  tags=$(openstack image show "$IMAGE_NAME" -f value -c tags || true)
  owner=$(openstack image show "$IMAGE_NAME" -f value -c owner || true)
  service_project=$(openstack project show service -f value -c id)

  if [ "$status" = "active" ] && [[ "$tags" == *amphora* ]] && [ "$owner" = "$service_project" ]; then
    echo "image-skip: $IMAGE_NAME (active, tagged amphora, service owned)"
    exit 0
  fi

  echo "image-delete-stale: $IMAGE_NAME (status=$status owner=$owner tags=$tags)"
  openstack image delete "$IMAGE_NAME" || true
  sleep 2
fi

echo "image-create: $IMAGE_NAME (tag=amphora project=service)"
openstack image create "$IMAGE_NAME" \
  --disk-format qcow2 \
  --container-format bare \
  --private \
  --tag amphora \
  --project service \
  --file "$REMOTE_FILE" >/tmp/openstack-image-create-${IMAGE_NAME}.out

for _ in $(seq 1 180); do
  status=$(openstack image show "$IMAGE_NAME" -f value -c status 2>/dev/null || true)
  case "$status" in
    active)
      echo "image-active: $IMAGE_NAME"
      exit 0
      ;;
    queued|saving|uploading|importing)
      sleep 5
      ;;
    '')
      sleep 2
      ;;
    *)
      echo "image-failed: $IMAGE_NAME status=$status" >&2
      exit 1
      ;;
  esac
done

echo "image-timeout: $IMAGE_NAME status=${status:-unknown}" >&2
exit 1
EOS
