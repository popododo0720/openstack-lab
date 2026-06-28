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
variable "external_network_cidr" {
  type    = string
  default = "192.168.0.0/24"
}
variable "external_gateway" {
  type    = string
  default = "192.168.0.1"
}
variable "external_dns" {
  type    = list(string)
  default = ["8.8.8.8", "1.1.1.1"]
}
variable "external_allocation_pools" {
  type = list(object({
    start = string
    end   = string
  }))
  default = [
    {
      start = "192.168.0.24"
      end   = "192.168.0.29"
    },
    {
      start = "192.168.0.42"
      end   = "192.168.0.51"
    },
    {
      start = "192.168.0.53"
      end   = "192.168.0.57"
    },
  ]
}

variable "external_provider_network_type" {
  type    = string
  default = "vlan"
}

variable "external_provider_physical_network" {
  type    = string
  default = "external"
}

variable "external_provider_segmentation_id" {
  type    = number
  default = 100
}

variable "private_external_enabled" {
  type    = bool
  default = false
}

variable "private_external_network_name" {
  type    = string
  default = "private-external-net"
}

variable "private_external_subnet_name" {
  type    = string
  default = "private-external-subnet"
}

variable "private_external_network_cidr" {
  type    = string
  default = "10.99.0.0/24"
}

variable "private_external_gateway" {
  type    = string
  default = "10.99.0.1"
}

variable "private_external_allocation_pools" {
  type = list(object({
    start = string
    end   = string
  }))
  default = [
    {
      start = "10.99.0.100"
      end   = "10.99.0.200"
    },
  ]
}

variable "private_external_provider_network_type" {
  type    = string
  default = "vlan"
}

variable "private_external_provider_physical_network" {
  type    = string
  default = "external"
}

variable "private_external_provider_segmentation_id" {
  type    = number
  default = 200
}

variable "tenant_network_cidr" {
  type    = string
  default = "172.16.0.0/24"
}
variable "tenant_dns" {
  type    = list(string)
  default = ["8.8.8.8"]
}

variable "octavia_amphora_image_url" {
  type    = string
  default = ""
}

variable "octavia_amphora_image_username" {
  type    = string
  default = "admin"
}

variable "octavia_amphora_image_password" {
  type      = string
  sensitive = true
  default   = "CHANGEME_PASSWORD"
}
