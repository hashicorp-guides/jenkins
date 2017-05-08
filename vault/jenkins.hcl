path "auth/approle/role/java-example/secret-id" {
  capabilities = ["read","create","update"]
}

path "secret/github" {
  capabilities = ["read"]
}

