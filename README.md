# Jenkins Integration Guide with the Hashicorp Suite

## Introduction

### What is Jenkins?
Jenkins is a common Continuous Integration and Continuous delivery tool, generally used to build and test software projects.

### What are the high level issues that this guide addresses?
#### With Vault
Building and testing software projects requires access to secrets. Jenkins has the concept of a "Credential store", which is static in nature and has different permission levels to store credentials. These secrets are stored in the underlying filesystem hashed. It requires an administrator to load them manually, and it is a single attack vector for potentially compromising credentials.

By using Vault, an homogeneous workflow can be used to consume credentials in testing and production systems. Credentials are dynamic in nature, short lived, and can be revoked easily. Access to credentials is programmatical, and as such reduces the difference between the way credentials are consumed in different environments. Policy is handled centrally in Vault.

#### With Nomad
Being a Java Application, is an excellent candidate to be scheduled in Vault as a long running service, without the need of building and maintaining containers.

Jenkins also schedules a number of short running batch jobs for testing. There is a plugin available to schedule jobs in Nomad to run tests.

#### With Consul
As service discovery, to monitor and use the DNS interface to consume services.

### Requirements
- A Nomad cluster running, with a client supporting scheduling Java tasks. Use the **nomad node-status** command to verify capabilities on a particular Nomad node.

```
$ nomad node-status a6ae8df0
ID      = a6ae8df0
Name    = node-3.nomad.example.net
Class   = <none>
DC      = dc1
Drain   = false
Status  = ready
Drivers = docker,exec,java,raw_exec
Uptime  = 475h11m48s

Allocated Resources
CPU            Memory           Disk             IOPS
2400/4800 MHz  768 MiB/925 MiB  500 MiB/551 MiB  0/0

Allocation Resource Utilization
CPU         Memory
7/4800 MHz  527 MiB/925 MiB

Host Resource Utilization
CPU           Memory           Disk
190/4800 MHz  708 MiB/926 MiB  6.3 GiB/14 GiB

Allocations
ID        Eval ID   Job ID   Task Group  Desired Status  Client Status
fcf788f6  49c820b4  jenkins  web         run             running
```
The Oracle JVM is recommended for performance reasons, although OpenJDK/Icedtea will work fine.

- A running and unsealed Vault cluster.
- A running Consul cluster, using dnsmasq to forward DNS queries. 


All of these can be deployed using the hashistack module available in https://github.com/hashicorp-modules/hashi-stack-aws

### Nomad integration with Consul and Vault
Scheduled tasks will benefit from both the Consul and Vault integrations in Nomad. This is not a requirement (except for certain sections of the guide), but it will benefit the user experience, as some sections of the guide will assume Consul URLs.

As an example of the Vault / Consul stanzas is available below:

```hcl
consul {
  address = "127.0.0.1:8500"
  auto_advertise = true

  server_auto_join = false
  client_auto_join = false
}

vault {
  enabled          = true
  address          = "https://vault.service.consul:8200"
  create_from_role = "nomad-cluster"
  token            = "1b6a5b29-e343-5031-76a1-cc71ed1a298d"
}
```

The **nomad-cluster** role is available on the *vault* directory. It allows creation of tokens from a number of pre-defined policies. This role, needs to be created in advanced in Vault, as well as a policy to allow Vault to create tokens, and a Token for each Nomad server.

An example of the nomad-cluster Vault role is available below:
```json
{
  "allowed_policies": "jenkins,default,github",
  "disallowed_policies": "nomad-server",
  "explicit_max_ttl": 0,
  "name": "nomad-cluster",
  "orphan": false,
  "period": 259200,
  "renewable": true
}
``` 

This should be imported into Vault using the following command (as an authenticated call):
```bash
$ vault write /auth/token/roles/nomad-cluster @nomad-cluster-role.json
```
Where *nomad-cluster-role* is the file contain the json encoded description of the role.

Validate that your role was created succesfully using (as an authenticated call):

```bash
$ vault read auth/token/roles/nomad-cluster
Key                 Value
---                 -----
allowed_policies    [default github jenkins]
disallowed_policies [nomad-server]
explicit_max_ttl    0
name                nomad-cluster
orphan              false
path_suffix
period              259200
renewable           true
```

A policy should be created to allow Nomad to generate tokens for scheduled tasks. An example of the policy (as described on the Nomad documention) is included in the *vault* directory and copied below:
```hcl

# Allow creating tokens under "nomad-cluster" role. The role name should be
# updated if "nomad-cluster" is not used.
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}

# Allow looking up "nomad-cluster" role. The role name should be updated if
# "nomad-cluster" is not used.
path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}

# Allow looking up the token passed to Nomad to validate # the token has the
# proper capabilities. This is provided by the "default" policy.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow looking up incoming tokens to validate they have permissions to access
# the tokens they are requesting. This is only required if
# `allow_unauthenticated` is set to false.
path "auth/token/lookup" {
  capabilities = ["update"]
}

# Allow revoking tokens that should no longer exist. This allows revoking
# tokens for dead tasks.
path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}

# Allow checking the capabilities of our own token. This is used to validate the
# token upon startup.
path "sys/capabilities-self" {
  capabilities = ["update"]
}

# Allow our own token to be renewed.
path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

Import this policy into vault using (as an authenticated call):
```bash
$ vault policy-write nomad-server nomad-server-policy.hcl
```
where *nomad-server-policy.hcl* is the file containing the aforementioned policy.

Validate the policy was properly imported with (as an authenticated call):
```bash
$ vault policies nomad-server
```
and verify the full output.

Finally, you need to generate Vault tokens for your Nomad agents, using:
```bash
$ vault token-create -policy nomad-server -period 72h
Key             Value
---             -----
token           f74ae7f3-cc4f-c906-142a-b2e778ff6185
token_accessor  841721c6-f0a8-41e8-7c4f-97d7d6b31a41
token_duration  72h0m0s
token_renewable true
token_policies  [default nomad-server]
```

## Running a Jenkins Master on Nomad
Being a Java application, Nomad can run Jenkins with the Java driver without the need for any further abstraction (i.e. Docker, RKT, Qemu or LXC) with a reasonable amount of isolation (cgroups, namespaces, and chroot) augmenting the JVM. It's worth noting that Jenkins is a stateful process that store a number of configuration files.

The use of ephemeral disk is required to provide a level of persistance, but it's not a highly available storage. If a node became unavailable before it was drained, the task would be started with a fresh directory. A couple of options to consider would be:

- Have regular backups of your Jenkins datastore (potentially using the thinBackup plugin or the SCM Sync Configuration plugin). These would be supported in principle by Jenkins but require manual intervention.
- Maintain your datastore in version control, and clone the repository automatically with Git.

Two Nomad job examples are provided in the Nomad folder:
- jenkins-java.nomad: Starts the process normally using a Java driver, you'll need to find the initial administrator password in the stderr log inside the allocation and use it to set up Jenkins.
- jenkins-sh.nomad: Clones a repository from Github inside the allocation before starting Jenkins, in order to provide a restore. The process consumes the GitHub personal access token stored in Vault, in *secret/github* as the *pan* key. This secret should be manually loaded in GitHub previous to scheduling the job.

Both jobs register a Jenkins service in Consul, which later can be used to access the jenkins page in http://jenkins.service.consul:8080 by querying the DNS name through the Consul interface.



