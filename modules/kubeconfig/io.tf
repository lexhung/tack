variable "admin-key-pem" {}
variable "admin-pem" {}
variable "ca-pem" {}
variable "master-elb" {}
variable "name" {}
variable "build-dir" {}

output "kubeconfig" { value = "${ data.template_file.kubeconfig.rendered }" }
