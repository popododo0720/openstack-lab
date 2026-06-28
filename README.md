# openstack-lab

Kolla-Ansible OpenStack + Ceph HCI 배포 자동화 (lab/reference).

VMware → OpenStack 마이그레이션 운영에 사용한 배포 플레이북 기반.

## 구성
- `00~14-*.yml` : SSH/base/docker/Ceph/Kolla 단계별 Ansible 플레이북
- `terraform/`   : base/instance/octavia/vjailbreak provisioning
- `config/`      : cinder/skyline/masakari 등 서비스 설정
- `scripts/`     : ceph dashboard 등 보조 스크립트
- `grafana-dashboards/` : 모니터링 대시보드

> 비밀번호/시크릿은 `CHANGEME_*` placeholder로 치환됨. 실제 배포 시 교체 필요.
