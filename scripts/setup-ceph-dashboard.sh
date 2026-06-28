#!/bin/bash

printf 'CHANGEME_PASSWORD' | ceph dashboard ac-user-set-password admin -i - --force-password
