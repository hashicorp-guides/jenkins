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
- A Nomad cluster running, with a client supporting scheduling Java tasks. Use the *nomad node-status* command to verify capabilities on a particular Nomad node.

```
$ *nomad node-status a6ae8df0*
ID      = a6ae8df0
Name    = node-3.nomad.example.net
Class   = <none>
DC      = dc1
Drain   = false
Status  = ready
Drivers = docker,exec,*java*,raw_exec
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
