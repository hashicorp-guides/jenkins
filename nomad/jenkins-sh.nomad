job "jenkins-beta" {
  type = "service"
    datacenters = ["dc1"]
    update {
      stagger      = "30s"
        max_parallel = 1
    }
  constraint {
    attribute = "${driver.java.version}"
    operator  = ">"
    value     = "1.7.0"
  }
  group "web" {
    count = 1
      ephemeral_disk {
       migrate = true
       size    = "500"
       sticky  = true

     }
    task "frontend" {
      env {
        HTTP_PORT = 8087
        GITHUB_REPO = "ncorrare/jenkins-config"
      }
      vault {
        policies = ["github"]

        change_mode   = "noop"
      }
      driver = "exec"
      config {
        command  = "/bin/bash"
        args     = ["local/start_jenkins.sh"]
      }
      artifact {
        source = "https://raw.githubusercontent.com/hashicorp-guides/jenkins/nomad/master/start_jenkins.sh"

        options {
          checksum = "sha256:6d59b984fea4f8adbb01ef3f8d3be95781cdd2d3046554b8a427393beab433ae"
        }
      }
      service {
        # This tells Consul to monitor the service on the port
        # labled "http". 
        port = "http"
        name = "jenkins-beta"

        check {
          type     = "http"
          path     = "/login"
          interval = "10s"
          timeout  = "2s"
        }
    }

      resources {
          cpu    = 2400 # MHz
          memory = 768 # MB
          network {
            mbits = 100
            port "http" {
                static = 8087
            }
            port "slave" {
              static = 5050
            }
          }
        }
      }
  }
}
