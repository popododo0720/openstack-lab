output "internal_network_id" {
  value = openstack_networking_network_v2.internal.id
}

output "internal_subnet_id" {
  value = openstack_networking_subnet_v2.internal.id
}

output "router_id" {
  value = openstack_networking_router_v2.main.id
}

output "internal_vm_id" {
  value = openstack_compute_instance_v2.internal_vm.id
}

output "internal_vm_fixed_ip" {
  value = try(openstack_networking_port_v2.internal_vm.all_fixed_ips[0], null)
}
