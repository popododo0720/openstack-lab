data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

data "openstack_networking_secgroup_v2" "test" {
  name = var.security_group_name
}

data "openstack_images_image_v2" "vjailbreak" {
  name        = "vjailbreak-golden-v0.4.5-dhcp"
  most_recent = true
}

data "openstack_compute_flavor_v2" "vjailbreak" {
  name = "t3.2xlarge"
}
