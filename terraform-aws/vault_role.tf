resource "null_resource" "jenkins_role" {
  # Changes to any policy should review if the roles exist
  triggers {
    vault_policies = "${join(",", vault_policy.*)}"
  }

  provisioner "local-exec" {
    # Check if the policies exist and if not create them. Dummy for the time being
    inline = [
      "curl -H \"X-Vault-Token: $(cat ~/.vault-token)\" -X GET ${VAULT_ADDR}/v1/auth/role/jenkins || curl -H \"X-Vault-Token: $(cat ~/.vault-token)\" -X POST ${VAULT_ADDR}/v1/auth/role/jenkins",
    ]
  }
}

resource "null_resource" "nomad-cluster-role" {
  # Changes to any policy should review if the roles exist
  triggers {
    vault_policies = "${join(",", vault_policy.*)}"
  }

  provisioner "local-exec" {
    # Check if the policies exist and if not create them. Dummy for the time being
    inline = [
      "curl -H \"X-Vault-Token: $(cat ~/.vault-token)\" -X GET ${VAULT_ADDR}/v1/auth/role/jenkins || curl -H \"X-Vault-Token: $(cat ~/.vault-token)\" -X POST ${VAULT_ADDR}/v1/auth/role/jenkins",
    ]
  }
}
