# ===========================================
# Provider/External Network only (no tenant overlay network)
# ===========================================
resource "openstack_networking_network_v2" "external" {
  name           = "external-net"
  admin_state_up = true
  shared         = true
  external       = true
  segments {
    network_type     = var.external_provider_network_type
    physical_network = var.external_provider_physical_network
    segmentation_id  = var.external_provider_segmentation_id
  }
}

resource "openstack_networking_subnet_v2" "external" {
  name            = "external-subnet"
  network_id      = openstack_networking_network_v2.external.id
  cidr            = var.external_network_cidr
  gateway_ip      = var.external_gateway
  dns_nameservers = var.external_dns
  enable_dhcp     = true
  dynamic "allocation_pool" {
    for_each = var.external_allocation_pools
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }
}

resource "openstack_networking_network_v2" "private_external" {
  count          = var.private_external_enabled ? 1 : 0
  name           = var.private_external_network_name
  admin_state_up = true
  shared         = true
  external       = true
  segments {
    network_type     = var.private_external_provider_network_type
    physical_network = var.private_external_provider_physical_network
    segmentation_id  = var.private_external_provider_segmentation_id
  }
}

resource "openstack_networking_subnet_v2" "private_external" {
  count           = var.private_external_enabled ? 1 : 0
  name            = var.private_external_subnet_name
  network_id      = openstack_networking_network_v2.private_external[0].id
  cidr            = var.private_external_network_cidr
  gateway_ip      = var.private_external_gateway
  dns_nameservers = var.external_dns
  enable_dhcp     = true
  dynamic "allocation_pool" {
    for_each = var.private_external_allocation_pools
    content {
      start = allocation_pool.value.start
      end   = allocation_pool.value.end
    }
  }
}
