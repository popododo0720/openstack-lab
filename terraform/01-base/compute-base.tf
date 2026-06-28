# ===========================================
# 이미지 업로드는 terraform이 아닌 terraform/upload-images.sh 가 담당한다.
# 01-base terraform 은 네트워크 / 보안그룹 / 플레이버 / 키페어만 관리한다.
# ===========================================

# ===========================================
# 플레이버
# AWS T-series naming with OpenStack local disk sizes for test workloads
# ===========================================
resource "openstack_compute_flavor_v2" "small" {
  name      = "t3.small"
  ram       = 2048
  vcpus     = 2
  disk      = 20
  is_public = true
}

resource "openstack_compute_flavor_v2" "medium" {
  name      = "t3.medium"
  ram       = 4096
  vcpus     = 2
  disk      = 40
  is_public = true
}

# ===========================================
# SSH 키페어
# ===========================================
resource "openstack_compute_keypair_v2" "test" {
  name = "test-keypair"
}

# ===========================================
# VM용 플레이버 (Alloy 포함)
# ===========================================
resource "openstack_compute_flavor_v2" "large" {
  name      = "t3.large"
  ram       = 8192
  vcpus     = 2
  disk      = 80
  is_public = true
}

resource "openstack_compute_flavor_v2" "aws_extra" {
  for_each = {
    "t3.nano" = {
      ram   = 512
      vcpus = 2
      disk  = 8
    }
    "t3.micro" = {
      ram   = 1024
      vcpus = 2
      disk  = 10
    }
    "t3.xlarge" = {
      ram   = 16384
      vcpus = 4
      disk  = 160
    }
    "t3.2xlarge" = {
      ram   = 32768
      vcpus = 8
      disk  = 320
    }
    "m5.large" = {
      ram   = 8192
      vcpus = 2
      disk  = 80
    }
    "m5.xlarge" = {
      ram   = 16384
      vcpus = 4
      disk  = 160
    }
    "m5.2xlarge" = {
      ram   = 32768
      vcpus = 8
      disk  = 320
    }
    "c5.large" = {
      ram   = 4096
      vcpus = 2
      disk  = 40
    }
    "c5.xlarge" = {
      ram   = 8192
      vcpus = 4
      disk  = 80
    }
    "c5.2xlarge" = {
      ram   = 16384
      vcpus = 8
      disk  = 160
    }
    "r5.large" = {
      ram   = 16384
      vcpus = 2
      disk  = 160
    }
    "r5.xlarge" = {
      ram   = 32768
      vcpus = 4
      disk  = 320
    }
    "r5.2xlarge" = {
      ram   = 65536
      vcpus = 8
      disk  = 640
    }
  }

  name      = each.key
  ram       = each.value.ram
  vcpus     = each.value.vcpus
  disk      = each.value.disk
  is_public = true
}
