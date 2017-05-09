resource "vault_policy" "github" {
  name = "github"

  policy = <<EOT
path "secret/github" {
  capabilities = ["read"]
}
EOT
}


resource "vault_policy" "jenkins" {
  name = "jenkins"

  policy = <<EOT
path "auth/approle/role/java-example/secret-id" {
  capabilities = ["read","create","update"]
}

path "secret/github" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "java-example" {
  name = "java-example"

  policy = <<EOT
path "secret/hello" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_policy" "nomad-server" {
  name = "nomad-server"

  policy = <<EOT
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}

path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/lookup" {
  capabilities = ["update"]
}

path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

