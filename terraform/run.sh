#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}"
IMAGE_DIR="${TERRAFORM_DIR}/images"
INVENTORY_FILE="${TERRAFORM_DIR}/../inventory.ini"

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
NEXUS_USER="admin"
NEXUS_PASSWORD='CHANGEME_PASSWORD'

usage() {
    echo "Usage: $0 <number|folder> [plan|apply|destroy]"
    echo ""
    echo "  $0 01           # 01-base terraform apply"
    echo "  $0 01 plan      # 01-base terraform plan"
    echo "  $0 01 destroy   # 01-base terraform destroy"
    echo "  $0 all          # apply modules 01-base through 05-vjailbreak"
    echo "  $0 all plan     # plan modules 01-base through 05-vjailbreak"
    echo ""
    echo "Folders:"
    ls -d ${TERRAFORM_DIR}/[0-9]*/ 2>/dev/null | xargs -I{} basename {}
    exit 1
}

ensure_01_base_images() {
    mkdir -p "${IMAGE_DIR}"

    local -a image_map=(
        "cirros-0.6.3-x86_64-disk.img|${NEXUS_RAW_BASE_URL}/cirros-0.6.3-x86_64-disk.img"
        "ubuntu-24.04-noble-amd64.img|${NEXUS_RAW_BASE_URL}/ubuntu-24.04-noble-amd64.img"
        "debian-12-bookworm-genericcloud-amd64.qcow2|${NEXUS_RAW_BASE_URL}/debian-12-bookworm-genericcloud-amd64.qcow2"
        "rocky-9-genericcloud-base.qcow2|${NEXUS_RAW_BASE_URL}/rocky-9-genericcloud-base.qcow2"
        "centos-stream-9-genericcloud.qcow2|${NEXUS_RAW_BASE_URL}/centos-stream-9-genericcloud.qcow2"
        "alpine-3.19.8-nocloud-cloudinit.qcow2|${NEXUS_RAW_BASE_URL}/alpine-3.19.8-nocloud-cloudinit.qcow2"
        "vjailbreak-golden-v0.4.5-dhcp.qcow2|${NEXUS_RAW_BASE_URL}/vjailbreak-golden-v0.4.5-dhcp.qcow2"
        "windows-10-openstack.qcow2|${NEXUS_RAW_BASE_URL}/windows-10-openstack.qcow2"
        "windows-11-openstack.qcow2|${NEXUS_RAW_BASE_URL}/windows-11-openstack.qcow2"
    )

    echo "=== [01-base] ensure local image cache ==="
    for item in "${image_map[@]}"; do
        IFS='|' read -r filename url <<< "$item"
        local target="${IMAGE_DIR}/${filename}"
        local partial="${target}.part"

        if [ -s "$target" ]; then
            echo "skip: $filename"
            continue
        fi

        echo "download: $filename"
        rm -f "$partial"
        curl -kfL --retry 3 --retry-delay 2 \
            -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
            -o "$partial" "$url"
        mv "$partial" "$target"
    done
    echo
}

run_terraform() {
    local dir="$1"
    local action="$2"
    local name
    name=$(basename "$dir")

    echo "=== [$name] terraform $action ==="
    python3 "${TERRAFORM_DIR}/render-tfvars-from-inventory.py" > /dev/null
    cd "$dir"

    if [ "$name" = "01-base" ] && [ "$action" != "destroy" ]; then
        ensure_01_base_images
    fi
    terraform init -input=false -no-color > /dev/null 2>&1

    case "$action" in
        plan)
            terraform plan -input=false
            ;;
        apply)
            terraform apply -input=false -auto-approve
            if [ "$name" = "01-base" ]; then
                echo
                echo "=== [01-base] upload images via OpenStack CLI on stack1 ==="
                "${TERRAFORM_DIR}/upload-images.sh"
            fi
            ;;
        destroy)
            terraform destroy -input=false -auto-approve
            ;;
        *)
            echo "Unknown action: $action"
            exit 1
            ;;
    esac

    echo "=== [$name] done ==="
    echo ""
}

[ -z "${1:-}" ] && usage

TARGET="$1"
ACTION="${2:-apply}"
SAFE_MODULES=(01-base 02-instance 03-internal-fip 04-octavia 05-vjailbreak)

if [ "$TARGET" = "all" ]; then
    for name in "${SAFE_MODULES[@]}"; do
        dir=$(ls -d ${TERRAFORM_DIR}/${name}/ 2>/dev/null | head -1)
        [ -n "$dir" ] || continue
        run_terraform "$dir" "$ACTION"
    done
else
    if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
        MATCHED=$(find "$TERRAFORM_DIR" -maxdepth 1 -type d -name "${TARGET}-*" ! -name "*.bak-*" | sort | head -1)
    else
        MATCHED=$(ls -d ${TERRAFORM_DIR}/${TARGET}/ 2>/dev/null | head -1)
    fi

    if [ -z "$MATCHED" ]; then
        echo "Folder not found: $TARGET"
        usage
    fi

    run_terraform "$MATCHED" "$ACTION"
fi
