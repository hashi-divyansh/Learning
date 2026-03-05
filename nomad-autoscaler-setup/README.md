# Nomad Autoscaler Setup with OrbStack

Learn HashiCorp Nomad Autoscaler using OrbStack VMs. Provisions 3 Nomad servers, 3 client nodes, and InfluxDB VM using Terraform + Ansible.

**Features:**
- Nomad cluster (3 servers + 3 clients) with Consul service discovery
- Custom-built autoscaler binary (Linux) with InfluxDB/Telegraf APM plugin
- InfluxDB 1.x for time-series metrics collection
- Telegraf agents on all nodes collecting system and Docker metrics
- HAProxy load balancer with dynamic service discovery

## Quick Start

**Prerequisites:** macOS with OrbStack, Terraform, Python 3, Ansible, SSH key pair

**Setup Cluster:**
```bash
make provision
```

This command runs Terraform to create VMs, generates Ansible inventory, and configures all nodes. Takes ~5-8 minutes.

**Verify Cluster:**
```bash
orb -m server-vm-0 nomad server members
orb -m server-vm-0 nomad node status
```

**Access UIs:**
- Nomad: http://localhost:4646/ui/jobs
- Consul: http://server-vm-0.orb.local:8500/ui (Service discovery & health checks)
- InfluxDB API: http://influxdb-vm.orb.local:8086 (Time-series metrics storage)
- HAProxy Load Balancer Stats: http://client-vm-1.orb.local:1936 (allocated dynamically to client nodes)

## Test Autoscaling

**Note:** The autoscaler runs as a native systemd service on server-vm-0 using your custom binary with InfluxDB APM plugin.

**Deploy jobs:**
```bash
# The autoscaler is already running as systemd service - no need to run autoscaler.nomad.hcl
nomad job run jobs/webapp-autoscale.nomad.hcl
nomad job run jobs/load-balancer.nomad.hcl  # Load balancer with service discovery
```

**Generate load:**
```bash
# Access through load balancer (automatically discovers all webapp instances)
make load-test WEBAPP_URL=http://localhost:8080
```

**Monitor scaling and service discovery:**
```bash
nomad job status webapp
# Check registered services in Consul
curl http://server-vm-0.orb.local:8500/v1/catalog/service/webapp | jq .

# Check autoscaler status and logs
orb -m server-vm-0 systemctl status nomad-autoscaler
orb -m server-vm-0 journalctl -u nomad-autoscaler -f
```

**View HAProxy stats:**
```bash
# Access HAProxy stats UI (port 1936)
nomad alloc logs <load-balancer-allocation-id> haproxy
```

## InfluxDB Metrics Verification

**Check InfluxDB is collecting metrics:**
```bash
# List databases
curl -G 'http://influxdb-vm.orb.local:8086/query' --data-urlencode "q=SHOW DATABASES"

# Query Telegraf metrics (system metrics from all nodes)
curl -G 'http://influxdb-vm.orb.local:8086/query' --data-urlencode "db=telegraf" --data-urlencode "q=SELECT * FROM cpu LIMIT 5"

# Query Nomad database (used by autoscaler)
curl -G 'http://influxdb-vm.orb.local:8086/query' --data-urlencode "db=nomad" --data-urlencode "q=SHOW MEASUREMENTS"

# Check Telegraf agent status on any node
orb -m client-vm-0 systemctl status telegraf
```

## Clean Up

```bash
make destroy
```

---

**Project file structure?**
```
nomad-autoscaler-setup/
├── main.tf                      # Terraform config (VMs: 3 servers, 3 clients, influxdb)
├── cloud-init-bootstrap.yaml.tmpl # Minimal SSH + Python bootstrap for all VMs
├── bin/nomad-autoscaler         # Your custom-built autoscaler binary (Linux) with InfluxDB plugin
├── ansible/                     # VM configuration via Ansible
│   ├── inventory/               # Dynamic inventory generation
│   ├── playbooks/               # Ansible playbooks
│   ├── roles/                   # Ansible roles
│   │   ├── base/                # DNS and host configuration
│   │   ├── consul/              # Consul servers and clients
│   │   ├── nomad_server/        # Nomad server setup
│   │   ├── nomad_client/        # Nomad client + Docker
│   │   ├── influxdb/            # InfluxDB 1.x time-series database
│   │   ├── telegraf/            # Telegraf agents for metric collection
│   │   └── nomad_autoscaler/    # Custom autoscaler as systemd service
│   └── group_vars/              # Variable definitions
├── jobs/                        # Nomad job files
│   ├── autoscaler.nomad.hcl     # (Not used - autoscaler runs as systemd service)
│   ├── webapp-autoscale.nomad.hcl # Sample webapp with autoscaling policy
│   └── load-balancer.nomad.hcl  # HAProxy with Consul service discovery
└── README.md                    # Quick start guide
```

---

**For detailed information, troubleshooting, and architecture details, see [question.md](question.md)**
**For Consul service discovery setup, see [CONSUL_SETUP.md](CONSUL_SETUP.md)**