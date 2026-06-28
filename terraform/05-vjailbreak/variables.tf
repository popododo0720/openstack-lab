variable "auth_url" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "RegionOne"
}

variable "external_network_name" {
  type    = string
  default = "external-net"
}

variable "security_group_name" {
  type    = string
  default = "test-secgroup"
}

variable "key_pair_name" {
  type    = string
  default = "test-keypair"
}
