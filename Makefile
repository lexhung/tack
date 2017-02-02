SHELL += -eu

BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

ENV ?= .no-cluster-configuration-provided.
CLUSTER_CONFIG := clusters/${ENV}/config
include ${CLUSTER_CONFIG}


# ∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨

AWS_REGION ?= us-west-1
COREOS_CHANNEL ?= stable
COREOS_VM_TYPE ?= hvm

CLUSTER_NAME ?= test
AWS_EC2_KEY_NAME ?= kz8s-$(CLUSTER_NAME)
TOP_LEVEL_DOMAIN ?= kz8s

PROXY_PORT ?= 8001

# CIDR_PODS: flannel overlay range
# - https://coreos.com/flannel/docs/latest/flannel-config.html
#
# CIDR_SERVICE_CLUSTER: apiserver parameter --service-cluster-ip-range
# - http://kubernetes.io/docs/admin/kube-apiserver/
#
# CIDR_VPC: vpc subnet
# - http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing
# - https://www.terraform.io/docs/providers/aws/r/vpc.html#cidr_block
#
CIDR_PODS ?= 10.2.0.0/16
CIDR_SERVICE_CLUSTER ?= 10.3.0.0/24
K8S_SERVICE_IP ?= 10.3.0.1
K8S_DNS_IP ?= 10.3.0.10

CIDR_VPC ?= 10.0.0.0/16
ETCD_IPS ?= 10.0.10.10,10.0.10.11,10.0.10.12

HYPERKUBE_IMAGE ?= quay.io/coreos/hyperkube
HYPERKUBE_TAG ?= v1.5.1_coreos.0

# Alternative:
# CIDR_PODS ?= "172.15.0.0/16"
# CIDR_SERVICE_CLUSTER ?= "172.16.0.0/24"
# K8S_SERVICE_IP ?= 172.16.0.1
# K8S_DNS_IP ?= 172.16.0.10

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

AWS_EC2_KEY_NAME := kz8s-$(CLUSTER_NAME)
INTERNAL_TLD := ${CLUSTER_NAME}.${TOP_LEVEL_DOMAIN}
BUILD_DIR := build/${INTERNAL_TLD}

TERRAFORM_TFVARS  := ${BUILD_DIR}/terraform.tfvars
TERRAFORM_TFPLAN  := ${BUILD_DIR}/terraform.tfplan
TERRAFORM_TFSTATE := ${BUILD_DIR}/terraform.tfstate

DIR_KEY_PAIR := ${BUILD_DIR}/keypair
DIR_SSL := ${BUILD_DIR}/cfssl
DIR_ADDONS := ${BUILD_DIR}/addons
DIR_TMP := ${BUILD_DIR}/tmp

CMD_TFOUTPUT := terraform output -state="${TERRAFORM_TFSTATE}"
# ∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨∨


## generate key-pair, variables and then `terraform apply`
all: prereqs create-keypair ssl init apply
	@echo "${GREEN}✓ terraform portion of 'make all' has completed ${NC}\n"
	@$(MAKE) wait-for-cluster
	@$(MAKE) ${DIR_ADDONS}
	@$(MAKE) create-addons
	# @$(MAKE) create-busybox
	kubectl get no
	@echo "${BLUE}❤ worker nodes may take several minutes to come online ${NC}"
	@$(MAKE) instances
	@echo "View nodes:"
	@echo "% make nodes"
	@echo "---"
	@echo "View uninitialized kube-system pods:"
	@echo "% make pods"
	@echo "---"
	@echo "View ec2 instance info:"
	@echo "% make instances"
	@echo "---"
	@echo "Status summaries:"
	@echo "% make status"

${DIR_SSL}:
	scripts/init-cfssl ${DIR_SSL} ${AWS_REGION} ${INTERNAL_TLD} ${K8S_SERVICE_IP}

${DIR_ADDONS}:
	$(eval CLUSTER_DOMAIN := $(shell ${CMD_TFOUTPUT} cluster-domain))
	$(eval DNS_SERVICE_IP := $(shell ${CMD_TFOUTPUT} dns-service-ip))
	@echo "${BLUE}❤ initialize add-ons ${NC}"
	@scripts/init-addons "${DIR_ADDONS}" "${INTERNAL_TLD}" "${CLUSTER_DOMAIN}" "${DNS_SERVICE_IP}"
	@echo "${GREEN}✓ initialize add-ons - success ${NC}\n"

## destroy and remove everything
clean: destroy delete-keypair close-proxy
	@-rm -rf .terraform ||:
	@-rm ${BUILD_DIR}/terraform.tfvars ||:
	@-rm ${BUILD_DIR}/terraform.tfplan ||:
	@-rm -rf ${DIR_TMP} ||:
	@-rm -rf ${DIR_KEY_PAIR} ||:
	@-rm -rf ${DIR_ADDONS} ||:
	@-rm -rf ${DIR_SSL} ||:


create-busybox:
	@echo "${BLUE}❤ create busybox test pod ${NC}"
	kubectl create -f test/pods/busybox.yml
	@echo "${GREEN}✓ create busybox test pod - success ${NC}\n"

## Close any running proxy instance
close-proxy:
	@echo "${BLUE}❤ Closing any existing proxy tunnel ${NC}"
	@-pkill -f "kubectl proxy"
	@echo "${GREEN}✓ Proxy closed ${NC}\n"

## start proxy and open kubernetes dashboard
dashboard:	close-proxy
	@scripts/dashboard ${PROXY_PORT}

## show instance information
instances: .tfstate
	@scripts/instances ${STATE_NAME} ${STATE_REGION}

## journalctl on etcd1
journal: .tfstate
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} "ssh ${STATE_BASTION_IP} journalctl -fl"

prereqs:
	@mkdir -p ${BUILD_DIR}
	aws --version
	@echo
	cfssl version
	@echo
	jq --version
	@echo
	kubectl version --client
	@echo
	terraform --version

## ssh into etcd1
ssh: .tfstate
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} "ssh ${STATE_ETCD1_IP}"

## ssh into bastion host
ssh-bastion: .tfstate
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP}

## status
status: instances
	kubectl get no
	kubectl cluster-info
	kubectl get po --namespace=kube-system
	kubectl get po
	kubectl exec busybox -- nslookup kubernetes

## create tls artifacts
ssl: ${DIR_SSL}

## create addons templates
init-addons: ${DIR_ADDONS}

## actually create addon resources with [kubectl]
create-addons: init-addons
	@echo "${BLUE}❤ create add-ons ${NC}"
	kubectl create -f ${BUILD_DIR}/addons/
	@echo "${GREEN}✓ create add-ons - success ${NC}\n"

## smoke it
test: test-ssl test-route53 test-etcd pods dns

wait-for-cluster:
	$(eval EXTERNAL_ELB := $(shell ${CMD_TFOUTPUT} external-elb))
	@echo "${BLUE}❤ wait-for-cluster ${NC}"
	@scripts/wait-for-cluster "${EXTERNAL_ELB}"
	@echo "${GREEN}✓ wait-for-cluster - success ${NC}\n"

include makefiles/*.mk

.DEFAULT_GOAL := help
.PHONY: all clean create-addons create-busybox instances journal prereqs ssh ssh-bastion ssl status test wait-for-cluster
