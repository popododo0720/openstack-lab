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

variable "internal_network_name" {
  type    = string
  default = "internal-net"
}

variable "internal_subnet_name" {
  type    = string
  default = "internal-subnet"
}

variable "internal_network_cidr" {
  type    = string
  default = "10.40.0.0/24"
}

variable "internal_gateway_ip" {
  type    = string
  default = "10.40.0.1"
}

variable "internal_dns" {
  type    = list(string)
  default = ["8.8.8.8", "1.1.1.1"]
}

variable "router_name" {
  type    = string
  default = "internal-router"
}

variable "instance_name" {
  type    = string
  default = "internal-vm-1"
}
