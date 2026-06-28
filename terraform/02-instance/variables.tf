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
