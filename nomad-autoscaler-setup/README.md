# Nomad Autoscaler Setup with OrbStack

Complete infrastructure setup for learning HashiCorp Nomad Autoscaler using OrbStack VMs, Terraform, and cloud-init.

## Architecture

**Infrastructure Components:**
- **3 Nomad Servers** (`server-vm-0`, `server-vm-1`, `server-vm-2`) - Clustered with 3-node quorum
- **3 Nomad Clients** (`client-vm-0`, `client-vm-1`, `client-vm-2`) - Worker nodes with Docker enabled
- **1 Prometheus VM** (`prometheus-vm`) - Metrics collection for autoscaling decisions

**Technology Stack:**
- **OS**: Debian Bookworm (ARM64)
- **Provisioning**: Terraform + cloud-init
- **Orchestration**: Nomad 1.7.3
- **Monitoring**: Prometheus 2.50.1
- **Container Runtime**: Docker (on client nodes)

## Prerequisites

- macOS with OrbStack installed
- Terraform >= 1.0
- Access to HashiCorp releases and GitHub

## Setup

### 1. Deploy Infrastructure

```bash
cd nomad-autoscaler-setup
terraform init
terraform apply -auto-approve
```

**Provisioning time:** ~3-5 minutes

### 2. Verify Cluster Health

Check Nomad servers formed quorum:
```bash
orb -m server-vm-0 nomad server members
```

Expected output:
```
Name              Address         Port  Status  Leader  Raft Version
server-vm-0.orb.  192.168.x.x     4648  alive   true    3
server-vm-1.orb.  192.168.x.x     4648  alive   false   3
server-vm-2.orb.  192.168.x.x     4648  alive   false   3
```

Check client nodes registered:
```bash
orb -m server-vm-0 nomad node status
```

### 3. Access UIs

**Nomad UI:**
- URL: http://localhost:4646/ui/jobs
- Direct (for curl/CLI): http://server-vm-0.orb.local:4646

**Prometheus UI:**
- URL: http://localhost:9090/graph
- Direct (for curl/CLI): http://prometheus-vm.orb.local:9090

> **Note:** Use `localhost` URLs in your browser. Chrome blocks `.local` domains due to security policies. The `.orb.local` URLs work for CLI tools like `curl` and `nomad` commands.

## DNS Configuration

OrbStack VMs use read-only `/etc/resolv.conf` symlinks. Cloud-init handles this by:
1. Deleting the symlink during `runcmd` phase
2. Writing new resolv.conf with public DNS (1.1.1.1, 8.8.8.8)
3. Ensures `wget` downloads work during provisioning

## Nomad Configuration

### Server Config (`/etc/nomad.d/server.hcl`)
- Bootstrap: 3-node quorum
- Auto-join: DNS-based discovery via `.orb.local`
- UI: Enabled on port 4646
- Advertise: Auto-discovery using `{{ GetPrivateIP }}`

### Client Config (`/etc/nomad.d/client.hcl`)
- Driver: Docker enabled
- Server discovery: Retry join to all 3 servers
- Auto-register with server pool

## Prometheus Targets

Configured to scrape:
- **Nomad Servers**: `server-vm-{0,1,2}.orb.local:4646/v1/metrics`
- **Nomad Clients**: `client-vm-{0,1,2}.orb.local:4646/v1/metrics`
- **Prometheus**: `localhost:9090`

## Next Steps: Nomad Autoscaler

### 1. Deploy Sample Application

Create a job with scaling policy (recommended starting point):

```hcl
job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 2

    scaling {
      enabled = true
      min     = 2
      max     = 10

      policy {
        cooldown            = "30s"
        evaluation_interval = "10s"

        check "cpu_usage" {
          source = "prometheus"
          query  = "avg(nomad_client_allocs_cpu_total_percent{task='web'})"

          strategy "target-value" {
            target = 70
          }
        }
      }
    }

    task "web" {
      driver = "docker"
      config {
        image = "nginx:alpine"
        ports = ["http"]
      }
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

### 2. Deploy Nomad Autoscaler

Run autoscaler as a Nomad job (recommended):

```hcl
job "autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

  group "autoscaler" {
    count = 1

    task "autoscaler" {
      driver = "docker"

      config {
        image = "hashicorp/nomad-autoscaler:latest"
        args  = ["agent", "-config", "/local/autoscaler.hcl"]
      }

      template {
        data = <<EOH
nomad {
  address = "http://server-vm-0.orb.local:4646"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://prometheus-vm.orb.local:9090"
  }
}

strategy "target-value" {
  driver = "target-value"
}
EOH
        destination = "local/autoscaler.hcl"
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
```

### 3. Generate Load & Observe Scaling

```bash
# Install load testing tool
brew install hey

# Generate load
hey -z 5m -c 50 http://server-vm-0.orb.local:8080

# Watch autoscaler decisions
nomad job status webapp
```

## Troubleshooting

### VMs not provisioning correctly
```bash
# Check cloud-init logs
orb -m server-vm-0 tail -100 /var/log/cloud-init-output.log

# Check DNS is working
orb -m server-vm-0 cat /etc/resolv.conf
orb -m server-vm-0 ping -c 1 releases.hashicorp.com
```

### Nomad not running
```bash
# Check service status
orb -m server-vm-0 systemctl status nomad

# Check logs
orb -m server-vm-0 journalctl -u nomad -n 50

# Verify binary exists
orb -m server-vm-0 nomad -v
```

### No cluster leader
```bash
# Check server members
orb -m server-vm-0 nomad server members

# Check if servers can reach each other
orb -m server-vm-0 ping server-vm-1.orb.local
```

### Rebuild entire infrastructure
```bash
terraform destroy -auto-approve
terraform apply -auto-approve
```

## File Structure

```
nomad-autoscaler-setup/
├── main.tf                      # Terraform config
├── cloud-init-server.yaml       # Server VM provisioning
├── cloud-init-client.yaml       # Client VM provisioning
├── cloud-init-prometheus.yaml   # Prometheus VM provisioning
├── jobs/                        # Nomad job files (create for autoscaler)
└── README.md                    # This file
```

## Learning Resources

- [Nomad Autoscaler Guide](https://developer.hashicorp.com/nomad/tools/autoscaling)
- [Nomad Scaling Policies](https://developer.hashicorp.com/nomad/docs/job-specification/scaling)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

## Clean Up

```bash
terraform destroy -auto-approve
```

This will remove all VMs and their data.
