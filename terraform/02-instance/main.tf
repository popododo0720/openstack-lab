# ===========================================
# 테스트 VM (이미지 부팅, provider-only)
# ===========================================
resource "openstack_compute_instance_v2" "test" {
  name            = "test-vm-1"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  key_pair        = "test-keypair"
  security_groups = [data.openstack_networking_secgroup_v2.test.name]

  network {
    uuid = data.openstack_networking_network_v2.external.id
  }
}

# ===========================================
# Cinder volume type (Ceph / NFS)
# ===========================================
resource "openstack_blockstorage_volume_type_v3" "ceph" {
  name = "ceph"

  extra_specs = {
    volume_backend_name = "rbd-1"
  }
}

resource "openstack_blockstorage_volume_type_v3" "nfs" {
  name = "nfs"

  extra_specs = {
    volume_backend_name = "nfs-1"
  }
}

# ===========================================
# 추가 데이터 볼륨 → VM에 attach
# ===========================================
resource "openstack_blockstorage_volume_v3" "data" {
  name        = "data-vol-1"
  size        = 10
  description = "test-vm-1 데이터 볼륨"
  volume_type = openstack_blockstorage_volume_type_v3.ceph.name
}

resource "openstack_compute_volume_attach_v2" "data" {
  instance_id = openstack_compute_instance_v2.test.id
  volume_id   = openstack_blockstorage_volume_v3.data.id
}

# ===========================================
# 볼륨 부팅 VM (Ceph)
# ===========================================
resource "openstack_blockstorage_volume_v3" "boot_ceph" {
  name        = "boot-ceph-vol-1"
  size        = 5
  image_id    = data.openstack_images_image_v2.cirros.id
  volume_type = openstack_blockstorage_volume_type_v3.ceph.name
}

resource "openstack_compute_instance_v2" "vol_boot_ceph" {
  name            = "vol-boot-ceph-vm-1"
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  key_pair        = "test-keypair"
  security_groups = [data.openstack_networking_secgroup_v2.test.name]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.boot_ceph.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = data.openstack_networking_network_v2.external.id
  }
}
