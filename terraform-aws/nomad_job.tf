resource "nomad_job" "jenkins" {
  jobspec = "${file("${path.module}/jenkins-java.nomad")}"
}
