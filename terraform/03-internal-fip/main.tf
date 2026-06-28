data "openstack_networking_network_v2" "external" {
  name = "external-net"
}

resource "openstack_networking_network_v2" "internal" {
  name           = var.internal_network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "internal" {
  name            = var.internal_subnet_name
  network_id      = openstack_networking_network_v2.internal.id
  cidr            = var.internal_network_cidr
  gateway_ip      = var.internal_gateway_ip
  dns_nameservers = var.internal_dns
  enable_dhcp     = true
}

resource "openstack_networking_router_v2" "main" {
  name                = var.router_name
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "internal" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.internal.id
}

resource "openstack_networking_port_v2" "internal_vm" {
  name               = "${var.instance_name}-port"
  network_id         = openstack_networking_network_v2.internal.id
  admin_state_up     = true
  security_group_ids = [data.openstack_networking_secgroup_v2.test.id]

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.internal.id
  }
}

resource "openstack_compute_instance_v2" "internal_vm" {
  name      = var.instance_name
  image_id  = data.openstack_images_image_v2.cirros.id
  flavor_id = data.openstack_compute_flavor_v2.small.id
  key_pair  = "test-keypair"

  network {
    port = openstack_networking_port_v2.internal_vm.id
  }
}
