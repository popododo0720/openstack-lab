output "loadbalancer_id" {
  value = openstack_lb_loadbalancer_v2.test.id
}

output "loadbalancer_provider" {
  value = var.octavia_provider
}

output "loadbalancer_vip" {
  value = openstack_lb_loadbalancer_v2.test.vip_address
}

output "loadbalancer_http_url" {
  value = "http://${openstack_lb_loadbalancer_v2.test.vip_address}/"
}

output "loadbalancer_url" {
  value = "http://${openstack_lb_loadbalancer_v2.test.vip_address}/"
}

output "loadbalancer_https_url" {
  value = "https://${openstack_lb_loadbalancer_v2.test.vip_address}/"
}

output "https_certificate_container_ref" {
  value = openstack_keymanager_container_v1.https.container_ref
}

output "backend_instance_id" {
  value = openstack_compute_instance_v2.backend.id
}

output "backend_ip" {
  value = try(openstack_networking_port_v2.backend.all_fixed_ips[0], null)
}
