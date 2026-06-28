data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

data "openstack_networking_subnet_v2" "external" {
  name = var.external_subnet_name
}

data "openstack_networking_secgroup_v2" "test" {
  name = var.security_group_name
}

data "openstack_images_image_v2" "backend" {
  name        = var.backend_image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "backend" {
  name = var.backend_flavor_name
}
