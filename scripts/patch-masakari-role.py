#!/usr/bin/env python3
# Inject custom masakari hostmonitor sudoers (crmadmin/cibadmin) into kolla masakari role,
# so kolla copies /etc/kolla/config/masakari/kolla_masakari_monitors_sudoers into the
# container at /etc/sudoers.d/. Idempotent. argv[1] = masakari role dir.
import sys
role = sys.argv[1]
rc = 0
jf = role + "/templates/masakari-hostmonitor.json.j2"
j = open(jf).read()
if "kolla_masakari_monitors_sudoers" in j:
    print("json.j2: already patched")
else:
    old = '        }{% endif %}\n    ],'
    new = ('        }{% endif %},\n'
           '        {\n'
           '            "source": "{{ container_config_directory }}/kolla_masakari_monitors_sudoers",\n'
           '            "dest": "/etc/sudoers.d/kolla_masakari_monitors_sudoers",\n'
           '            "owner": "root",\n'
           '            "perm": "0440"\n'
           '        }\n'
           '    ],')
    if j.count(old) == 1:
        open(jf + ".fxhci.bak", "w").write(j)
        open(jf, "w").write(j.replace(old, new, 1))
        print("json.j2: PATCHED")
    else:
        print("json.j2: ERROR anchor count=%d" % j.count(old)); rc = 1
cf = role + "/tasks/config.yml"
c = open(cf).read()
if "masakari-monitors sudoers" in c:
    print("config.yml: already patched")
else:
    marker = "- name: Copying over wsgi-masakari file for services"
    block = ('- name: Copying over masakari-monitors sudoers file\n'
             '  vars:\n'
             '    service_name: "masakari-hostmonitor"\n'
             '    service: "{{ masakari_services[service_name] }}"\n'
             '  copy:\n'
             '    src: "{{ item }}"\n'
             '    dest: "{{ node_config_directory }}/{{ service_name }}/kolla_masakari_monitors_sudoers"\n'
             '    mode: "0660"\n'
             '  become: true\n'
             '  when: service | service_enabled_and_mapped_to_host\n'
             '  with_first_found:\n'
             '    - files:\n'
             '        - "{{ node_custom_config }}/masakari/kolla_masakari_monitors_sudoers"\n'
             '      skip: true\n'
             '  notify:\n'
             '    - Restart masakari-hostmonitor container\n'
             '\n')
    if c.count(marker) == 1:
        open(cf + ".fxhci.bak", "w").write(c)
        open(cf, "w").write(c.replace(marker, block + marker, 1))
        print("config.yml: PATCHED")
    else:
        print("config.yml: ERROR marker count=%d" % c.count(marker)); rc = 1
sys.exit(rc)
