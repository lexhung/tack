variable "admin-key-pem" {}
variable "admin-pem" {}
variable "ca-pem" {}
variable "master-elb" {}
variable "name" {}
variable "dir-tmp" {}

output "kubeconfig" { value = "${ data.template_file.kubeconfig.rendered }" }
