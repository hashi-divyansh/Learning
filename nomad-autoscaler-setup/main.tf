terraform {
  required_providers {
    orbstack = {
      source  = "robertdebock/orbstack"
      version = ">= 3.1.0"
    }
  }
}

provider "orbstack" {}


# Create a machine that will be set as the default
resource "orbstack_machine" "client_vm" {
  count = 3
  name  = "client-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  # Cloud-init configuration - runs inside the VM during first boot
  cloud_init = file("${path.module}/cloud-init-client.yaml")
}

# Create another machine (not default)
resource "orbstack_machine" "server_vm" {
  count = 3
  name  = "server-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  # Cloud-init configuration - runs inside the VM during first boot
  cloud_init = file("${path.module}/cloud-init-server.yaml")
}

# Create Prometheus monitoring VM (separate for production-like setup)
resource "orbstack_machine" "prometheus_vm" {
  name  = "prometheus-vm"
  image = "debian:bookworm"

  # Cloud-init configuration - runs inside the VM during first boot
  cloud_init = file("${path.module}/cloud-init-prometheus.yaml")
}

# Output the client machines
output "client_machines" {
  value = orbstack_machine.client_vm[*].name
}

# Output server machines
output "server_machines" {
  value = orbstack_machine.server_vm[*].name
}

# Output Prometheus VM
output "prometheus_machine" {
  value = orbstack_machine.prometheus_vm.name
}

# Output access URLs
output "prometheus_url" {
  value       = "http://prometheus-vm.orb.local:9090"
  description = "Prometheus Web UI (after VMs boot)"
}

output "nomad_ui_url" {
  value       = "http://server-vm-0.orb.local:4646"
  description = "Nomad Web UI (after servers boot)"
}

