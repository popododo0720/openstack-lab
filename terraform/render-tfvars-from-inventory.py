#!/usr/bin/env python3
import ipaddress
import json
import shlex
from pathlib import Path


TF_ROOT = Path(__file__).resolve().parent
ROOT = TF_ROOT.parent
INVENTORY = ROOT / "inventory.ini"


def parse_inventory(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "all:vars" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip().strip("'").strip('"')
    return data


def parse_inventory_hosts(path: Path) -> dict[str, dict[str, str]]:
    hosts: dict[str, dict[str, str]] = {}
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "all":
            continue

        parts = shlex.split(line)
        if not parts:
            continue

        attrs: dict[str, str] = {}
        for token in parts[1:]:
            if "=" not in token:
                continue
            key, value = token.split("=", 1)
            attrs[key] = value
        hosts[parts[0]] = attrs
    return hosts


def split_words(value: str | None) -> list[str]:
    if not value:
        return []
    return [item for item in value.split() if item]


def first_host(cidr: str) -> str:
    net = ipaddress.ip_network(cidr, strict=False)
    return str(next(net.hosts()))


def host_offset(cidr: str, offset: int) -> str:
    net = ipaddress.ip_network(cidr, strict=False)
    if net.version != 4:
        raise ValueError("Only IPv4 is supported for Terraform inventory rendering")
    base = int(net.network_address)
    return str(ipaddress.ip_address(base + offset))


def default_external_pools(cidr: str) -> list[dict[str, str]]:
    return [
        {"start": host_offset(cidr, 24), "end": host_offset(cidr, 29)},
        {"start": host_offset(cidr, 42), "end": host_offset(cidr, 51)},
        {"start": host_offset(cidr, 53), "end": host_offset(cidr, 57)},
    ]


def parse_pools(value: str | None, cidr: str) -> list[dict[str, str]]:
    if not value:
        return default_external_pools(cidr)
    pools: list[dict[str, str]] = []
    for chunk in value.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        start, end = [item.strip() for item in chunk.split("-", 1)]
        pools.append({"start": start, "end": end})
    return pools


def parse_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "y", "on"}


def parse_int_or_null(value: str | None):
    if value is None or not value.strip():
        return None
    return int(value.strip())


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    inv = parse_inventory(INVENTORY)
    hosts = parse_inventory_hosts(INVENTORY)

    region = inv.get("region", "RegionOne")
    external_vip = inv["kolla_external_vip_address"]
    auth_url = inv.get("terraform_auth_url", f"https://{external_vip}:5000/v3")
    admin_password = inv["admin_password"]
    site_dns = split_words(inv.get("site_dns_servers")) or ["1.1.1.1", "8.8.8.8"]
    external_cidr = inv.get("external_network", "192.168.0.0/24")
    external_gateway = inv.get("external_gateway", first_host(external_cidr))
    local_registry = inv.get("local_registry", "")
    repo_host = inv.get("terraform_repo_host") or local_registry.split(":", 1)[0]
    repo_base_url = inv.get("terraform_repo_base_url", f"https://{repo_host}")
    raw_base_url = inv.get("terraform_raw_base_url", f"{repo_base_url}/repository/raw-hosted")

    common = {
        "auth_url": auth_url,
        "admin_password": admin_password,
        "region": region,
    }

    tf01 = {
        **common,
        "external_network_cidr": external_cidr,
        "external_gateway": external_gateway,
        "external_dns": site_dns,
        "tenant_dns": site_dns,
        "external_allocation_pools": parse_pools(inv.get("terraform_external_allocation_pools"), external_cidr),
        "external_provider_network_type": inv.get("terraform_external_provider_network_type", "vlan"),
        "external_provider_physical_network": inv.get("terraform_external_provider_physical_network", "external"),
        "external_provider_segmentation_id": parse_int_or_null(
            inv.get("terraform_external_provider_segmentation_id")
        ),
        "private_external_enabled": parse_bool(inv.get("terraform_private_external_enabled")),
        "private_external_network_name": inv.get("terraform_private_external_network_name", "private-external-net"),
        "private_external_subnet_name": inv.get("terraform_private_external_subnet_name", "private-external-subnet"),
        "private_external_network_cidr": inv.get("terraform_private_external_network", "10.99.0.0/24"),
        "private_external_gateway": inv.get("terraform_private_external_gateway", "10.99.0.1"),
        "private_external_allocation_pools": parse_pools(
            inv.get("terraform_private_external_allocation_pools"),
            inv.get("terraform_private_external_network", "10.99.0.0/24"),
        ),
        "private_external_provider_network_type": inv.get(
            "terraform_private_external_provider_network_type",
            "vlan",
        ),
        "private_external_provider_physical_network": inv.get(
            "terraform_private_external_provider_physical_network",
            "external",
        ),
        "private_external_provider_segmentation_id": parse_int_or_null(
            inv.get("terraform_private_external_provider_segmentation_id")
        ),
        "octavia_amphora_image_url": inv.get(
            "terraform_octavia_amphora_image_url",
            f"{raw_base_url}/openstack/octavia/amphora-x64-haproxy.qcow2",
        ),
    }

    tf03 = {
        **common,
        "internal_network_name": inv.get("terraform_internal_network_name", "internal-net"),
        "internal_subnet_name": inv.get("terraform_internal_subnet_name", "internal-subnet"),
        "router_name": inv.get("terraform_router_name", "internal-router"),
        "instance_name": inv.get("terraform_internal_instance_name", "internal-vm-1"),
    }

    internal_cidr = inv.get("terraform_internal_network_cidr", "10.40.0.0/24")
    tf03["internal_network_cidr"] = internal_cidr
    tf03["internal_gateway_ip"] = inv.get("terraform_internal_gateway_ip", first_host(internal_cidr))
    tf03["internal_dns"] = split_words(inv.get("terraform_internal_dns")) or site_dns

    external_network_name = inv.get("terraform_external_network_name", "external-net")
    external_subnet_name = inv.get("terraform_external_subnet_name", "external-subnet")
    key_pair_name = inv.get("terraform_key_pair_name", "test-keypair")
    security_group_name = inv.get("terraform_security_group_name", "test-secgroup")

    tf04 = {
        **common,
        "external_network_name": external_network_name,
        "external_subnet_name": external_subnet_name,
        "security_group_name": security_group_name,
        "key_pair_name": key_pair_name,
        "octavia_provider": inv.get("terraform_octavia_provider", "amphora"),
        "loadbalancer_name": inv.get("terraform_octavia_loadbalancer_name", "test-lb-1"),
        "backend_instance_name": inv.get("terraform_octavia_backend_instance_name", "octavia-web-1"),
        "backend_image_name": inv.get("terraform_octavia_backend_image_name", "ubuntu-24.04"),
        "backend_flavor_name": inv.get("terraform_octavia_backend_flavor_name", "t3.small"),
    }

    tf05 = {
        **common,
        "external_network_name": external_network_name,
        "security_group_name": security_group_name,
        "key_pair_name": key_pair_name,
    }

    write_json(TF_ROOT / "01-base" / "zz_inventory.auto.tfvars.json", tf01)
    write_json(TF_ROOT / "02-instance" / "zz_inventory.auto.tfvars.json", common)
    write_json(TF_ROOT / "03-internal-fip" / "zz_inventory.auto.tfvars.json", tf03)
    write_json(TF_ROOT / "04-octavia" / "zz_inventory.auto.tfvars.json", tf04)
    write_json(TF_ROOT / "05-vjailbreak" / "zz_inventory.auto.tfvars.json", tf05)

    print("Rendered:")
    print(TF_ROOT / "01-base" / "zz_inventory.auto.tfvars.json")
    print(TF_ROOT / "02-instance" / "zz_inventory.auto.tfvars.json")
    print(TF_ROOT / "03-internal-fip" / "zz_inventory.auto.tfvars.json")
    print(TF_ROOT / "04-octavia" / "zz_inventory.auto.tfvars.json")
    print(TF_ROOT / "05-vjailbreak" / "zz_inventory.auto.tfvars.json")


if __name__ == "__main__":
    main()
