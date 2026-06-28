output "instance_id" {
  value = openstack_compute_instance_v2.vjailbreak.id
}

output "external_ip" {
  value = openstack_networking_port_v2.vjailbreak.all_fixed_ips[0]
}

output "web_ui" {
  value = "https://${openstack_networking_port_v2.vjailbreak.all_fixed_ips[0]}/"
}

output "ssh" {
  value = "ubuntu@${openstack_networking_port_v2.vjailbreak.all_fixed_ips[0]}"
}
