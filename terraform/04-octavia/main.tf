resource "openstack_networking_port_v2" "backend" {
  name               = "${var.backend_instance_name}-port"
  network_id         = data.openstack_networking_network_v2.external.id
  admin_state_up     = true
  security_group_ids = [data.openstack_networking_secgroup_v2.test.id]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.external.id
  }
}

resource "openstack_compute_instance_v2" "backend" {
  name         = var.backend_instance_name
  image_id     = data.openstack_images_image_v2.backend.id
  flavor_id    = data.openstack_compute_flavor_v2.backend.id
  key_pair     = var.key_pair_name
  config_drive = true

  network {
    port = openstack_networking_port_v2.backend.id
  }

  user_data = <<-EOF
    #cloud-config
    write_files:
      - path: /var/www/html/index.html
        permissions: "0644"
        content: |
          octavia backend ok
      - path: /etc/systemd/system/octavia-test-web.service
        permissions: "0644"
        content: |
          [Unit]
          Description=Octavia test web server
          After=network-online.target
          Wants=network-online.target

          [Service]
          Type=simple
          ExecStart=/usr/bin/python3 -m http.server 80 --directory /var/www/html
          Restart=always

          [Install]
          WantedBy=multi-user.target
    runcmd:
      - systemctl daemon-reload
      - systemctl enable --now octavia-test-web.service
  EOF
}

resource "openstack_lb_loadbalancer_v2" "test" {
  name                  = var.loadbalancer_name
  vip_subnet_id         = data.openstack_networking_subnet_v2.external.id
  loadbalancer_provider = var.octavia_provider
  admin_state_up        = true
}

resource "openstack_lb_listener_v2" "http" {
  name            = var.listener_name
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.test.id
  admin_state_up  = true
}

resource "tls_private_key" "https" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "https" {
  private_key_pem       = tls_private_key.https.private_key_pem
  validity_period_hours = 8760
  early_renewal_hours   = 720
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]

  subject {
    common_name  = var.https_common_name
    organization = "SNU OpenStack Lab"
  }
}

resource "openstack_keymanager_secret_v1" "https_certificate" {
  name                 = "${var.loadbalancer_name}-tls-certificate"
  payload              = tls_self_signed_cert.https.cert_pem
  payload_content_type = "text/plain"
  secret_type          = "certificate"
}

resource "openstack_keymanager_secret_v1" "https_private_key" {
  name                 = "${var.loadbalancer_name}-tls-private-key"
  payload              = tls_private_key.https.private_key_pem
  payload_content_type = "text/plain"
  secret_type          = "private"
}

resource "openstack_keymanager_container_v1" "https" {
  name = "${var.loadbalancer_name}-tls-container"
  type = "certificate"

  secret_refs {
    name       = "certificate"
    secret_ref = openstack_keymanager_secret_v1.https_certificate.secret_ref
  }

  secret_refs {
    name       = "private_key"
    secret_ref = openstack_keymanager_secret_v1.https_private_key.secret_ref
  }
}

resource "openstack_lb_listener_v2" "https" {
  name                      = var.https_listener_name
  protocol                  = "TERMINATED_HTTPS"
  protocol_port             = 443
  loadbalancer_id           = openstack_lb_loadbalancer_v2.test.id
  default_tls_container_ref = openstack_keymanager_container_v1.https.container_ref
  admin_state_up            = true
}

resource "openstack_lb_pool_v2" "http" {
  name        = var.pool_name
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.http.id
}

resource "openstack_lb_pool_v2" "https" {
  name        = var.https_pool_name
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.https.id
}

resource "openstack_lb_member_v2" "backend" {
  name          = var.backend_instance_name
  pool_id       = openstack_lb_pool_v2.http.id
  address       = openstack_networking_port_v2.backend.all_fixed_ips[0]
  protocol_port = var.backend_port
  subnet_id     = data.openstack_networking_subnet_v2.external.id

  depends_on = [
    openstack_compute_instance_v2.backend
  ]
}

resource "openstack_lb_member_v2" "https_backend" {
  name          = "${var.backend_instance_name}-https"
  pool_id       = openstack_lb_pool_v2.https.id
  address       = openstack_networking_port_v2.backend.all_fixed_ips[0]
  protocol_port = var.backend_port
  subnet_id     = data.openstack_networking_subnet_v2.external.id

  depends_on = [
    openstack_compute_instance_v2.backend
  ]
}

resource "openstack_lb_monitor_v2" "http" {
  name           = var.monitor_name
  pool_id        = openstack_lb_pool_v2.http.id
  type           = "HTTP"
  delay          = 5
  timeout        = 3
  max_retries    = 3
  http_method    = "GET"
  url_path       = "/"
  expected_codes = "200"
}

resource "openstack_lb_monitor_v2" "https" {
  name           = var.https_monitor_name
  pool_id        = openstack_lb_pool_v2.https.id
  type           = "HTTP"
  delay          = 5
  timeout        = 3
  max_retries    = 3
  http_method    = "GET"
  url_path       = "/"
  expected_codes = "200"
}
