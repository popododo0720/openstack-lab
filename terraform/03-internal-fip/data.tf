data "openstack_networking_secgroup_v2" "test" {
  name = "test-secgroup"
}

data "openstack_images_image_v2" "cirros" {
  name        = "cirros-0.6.3"
  most_recent = true
}

data "openstack_compute_flavor_v2" "small" {
  name = "t3.small"
}
