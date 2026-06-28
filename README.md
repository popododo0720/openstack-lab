# openstack-lab

Kolla-Ansible OpenStack + Ceph HCI deployment automation (lab/reference).

Based on the deployment playbooks used in production VMware → OpenStack migration.

## Structure

- `00~14-*.yml` — Step-by-step Ansible playbooks (SSH / base / Docker / Ceph / Kolla)
- `terraform/` — base / instance / Octavia / vJailbreak provisioning
- `config/` — Service configs (Cinder, Skyline, Masakari, etc.)
- `scripts/` — Helper scripts (Ceph dashboard, etc.)
- `grafana-dashboards/` — Monitoring dashboards
