output "test_vm_id" {
  value = openstack_compute_instance_v2.test.id
}
output "data_volume_id" {
  value = openstack_blockstorage_volume_v3.data.id
}
output "vol_boot_ceph_vm_id" {
  value = openstack_compute_instance_v2.vol_boot_ceph.id
}
