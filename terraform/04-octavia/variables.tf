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

variable "external_subnet_name" {
  type    = string
  default = "external-subnet"
}

variable "security_group_name" {
  type    = string
  default = "test-secgroup"
}

variable "key_pair_name" {
  type    = string
  default = "test-keypair"
}

variable "octavia_provider" {
  type    = string
  default = "amphora"
}

variable "loadbalancer_name" {
  type    = string
  default = "test-lb-1"
}

variable "listener_name" {
  type    = string
  default = "test-lb-http-listener"
}

variable "https_listener_name" {
  type    = string
  default = "test-lb-https-listener"
}

variable "pool_name" {
  type    = string
  default = "test-lb-http-pool"
}

variable "https_pool_name" {
  type    = string
  default = "test-lb-https-pool"
}

variable "monitor_name" {
  type    = string
  default = "test-lb-http-monitor"
}

variable "https_monitor_name" {
  type    = string
  default = "test-lb-https-monitor"
}

variable "https_common_name" {
  type    = string
  default = "test-lb.local"
}

variable "backend_instance_name" {
  type    = string
  default = "octavia-web-1"
}

variable "backend_image_name" {
  type    = string
  default = "ubuntu-24.04"
}

variable "backend_flavor_name" {
  type    = string
  default = "t3.small"
}

variable "backend_port" {
  type    = number
  default = 80
}
