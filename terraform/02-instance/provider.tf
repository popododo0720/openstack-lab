provider "openstack" {
  auth_url    = var.auth_url
  user_name   = "admin"
  password    = var.admin_password
  tenant_name = "admin"
  domain_name = "Default"
  region      = var.region
  insecure    = true
}
