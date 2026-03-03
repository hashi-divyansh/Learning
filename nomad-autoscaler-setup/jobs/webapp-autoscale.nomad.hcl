# jobs/webapp-autoscale.nomad.hcl
job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1  # Start with 1 tasks

    scaling {
      enabled = true
      min     = 1
      max     = 10

      policy {
        cooldown            = "30s"
        evaluation_interval = "10s"

        check "cpu_usage" {
          source = "prometheus"
          query  = "avg(nomad_client_allocs_cpu_total_percent{task='web'})"

          strategy "target-value" {
            target = 30  # Scale when CPU > 30% just for testing ( to scaler quickly)
          }
        }
      }
    }

    network {
      port "http" {
        to = 80
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