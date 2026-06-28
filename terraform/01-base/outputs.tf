output "external_network_id" {
  value = openstack_networking_network_v2.external.id
}

output "external_network_name" {
  value = openstack_networking_network_v2.external.name
}

output "external_provider_segment" {
  value = {
    network_type     = var.external_provider_network_type
    physical_network = var.external_provider_physical_network
    segmentation_id  = var.external_provider_segmentation_id
  }
}

output "private_external_network_id" {
  value = var.private_external_enabled ? openstack_networking_network_v2.private_external[0].id : null
}

output "private_external_network_name" {
  value = var.private_external_enabled ? openstack_networking_network_v2.private_external[0].name : null
}

output "secgroup_name" {
  value = openstack_networking_secgroup_v2.test.name
}

output "flavor_small_id" {
  value = openstack_compute_flavor_v2.small.id
}

output "flavor_medium_id" {
  value = openstack_compute_flavor_v2.medium.id
}

output "aws_flavor_ids" {
  value = merge(
    {
      "t3.small"  = openstack_compute_flavor_v2.small.id
      "t3.medium" = openstack_compute_flavor_v2.medium.id
      "t3.large"  = openstack_compute_flavor_v2.large.id
    },
    { for name, flavor in openstack_compute_flavor_v2.aws_extra : name => flavor.id }
  )
}

output "keypair_name" {
  value = openstack_compute_keypair_v2.test.name
}

output "private_key" {
  value     = openstack_compute_keypair_v2.test.private_key
  sensitive = true
}
