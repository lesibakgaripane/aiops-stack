# Phase 1 – Data Collectors (LibreNMS, ONOS, Zabbix)

> Target path on your VM: /home/lesiba/aiops-stack

## 0) Prereqs (once per host)
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker

## 1) Create project structure
mkdir -p ~/aiops-stack/{compose,configs,volumes}
cd ~/aiops-stack

## 2) Put files in place
# Extract the ZIP you downloaded to ~/aiops-stack, then check:
ls -R

## 3) Edit secrets
nano .env
# Change all passwords and review timezones.

## 4) Bring up Phase 1 stack
docker compose -f compose/collectors.yml --env-file .env up -d

## 5) Verify
docker ps
docker compose -f compose/collectors.yml ps
docker logs librenms --tail=100
docker logs zabbix-server --tail=100
docker logs onos --tail=50

## 6) Access
LibreNMS:   http://<VM-IP>:8000
Zabbix:     http://<VM-IP>:8081
ONOS UI:    http://<VM-IP>:8181  (user: onos, pass: rocks)
ONOS CLI:   ssh -p 8101 karaf@<VM-IP>   (pass: karaf)

## 7) Next
- Add devices in LibreNMS (SNMP community from .env) and Zabbix (agent/SNMP).
- This Phase includes MariaDB only to support the collectors. The full Data Lake (Prometheus, Elasticsearch, Kibana) is Phase 2.
