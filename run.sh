#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./run.sh <playbook>"
    echo "  예: ./run.sh 02-docker-install"
    exit 1
fi

PLAYBOOK="$1"
# .yml 안 붙였으면 붙여줌
[[ "$PLAYBOOK" != *.yml ]] && PLAYBOOK="${PLAYBOOK}.yml"

if [ ! -f "$PLAYBOOK" ]; then
    echo "파일 없음: $PLAYBOOK"
    ls *.yml
    exit 1
fi

ansible-playbook -i inventory.ini "$PLAYBOOK" -v 2>&1 | tee ansible.log
