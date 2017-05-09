resource "vault_generic_secret" "hello" {
  path = "secret/hello"

  data_json = <<EOT
{
  "value": "Hello World! This secret is stored in Vault"
}
EOT
}
