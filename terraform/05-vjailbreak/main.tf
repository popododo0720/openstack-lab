resource "openstack_networking_port_v2" "vjailbreak" {
  name               = "vjailbreak-external-port"
  network_id         = data.openstack_networking_network_v2.external.id
  admin_state_up     = true
  security_group_ids = [data.openstack_networking_secgroup_v2.test.id]
}

resource "openstack_compute_instance_v2" "vjailbreak" {
  name         = "vjailbreak"
  image_id     = data.openstack_images_image_v2.vjailbreak.id
  flavor_id    = data.openstack_compute_flavor_v2.vjailbreak.id
  key_pair     = var.key_pair_name
  config_drive = true

  network {
    port = openstack_networking_port_v2.vjailbreak.id
  }
}
