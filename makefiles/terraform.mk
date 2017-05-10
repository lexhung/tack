.terraform: ; terraform get

${TERRAFORM_TFVARS}:
	@scripts/init-variables \
		${AWS_REGION} ${COREOS_CHANNEL} ${COREOS_VM_TYPE} ${AWS_EC2_KEY_NAME} \
		${INTERNAL_TLD} ${CLUSTER_NAME} `scripts/myip` ${CIDR_VPC} ${CIDR_PODS} \
		${CIDR_SERVICE_CLUSTER} ${K8S_SERVICE_IP} ${K8S_DNS_IP} ${ETCD_IPS} \
		${HYPERKUBE_IMAGE} ${HYPERKUBE_TAG} \
		${BUILD_DIR} ${DIR_SSL} ${DIR_KEY_PAIR} ${DIR_TMP}

## Read common state values from terraform.tfstate. This might different to
## values stored in configuration files due to changes did not applied.
.tfstate:
	$(eval STATE_BASTION_IP := $(shell ${CMD_TFOUTPUT} bastion-ip))
	$(eval STATE_INTERNAL_TLD := $(shell ${CMD_TFOUTPUT} internal-tld))
	$(eval STATE_NAME := $(shell ${CMD_TFOUTPUT} name))
	$(eval STATE_REGION := $(shell ${CMD_TFOUTPUT} region))
	$(eval STATE_ETCD1_IP := $(shell ${CMD_TFOUTPUT} etcd1-ip))

module.%:
	@echo "${BLUE}❤ make $@ - commencing${NC}"
	@time terraform apply -state="${TERRAFORM_TFSTATE}" -var-file="${TERRAFORM_TFVARS}" -target $@
	@echo "${GREEN}✓ make $@ - success${NC}"
	@sleep 5.2

## terraform apply
apply: plan
	@echo "${BLUE}❤ terraform apply - commencing${NC}"
	terraform apply -state="${TERRAFORM_TFSTATE}" -var-file="${TERRAFORM_TFVARS}"
	@echo "${GREEN}✓ make $@ - success${NC}"

## terraform destroy
destroy: ; terraform destroy -state=${TERRAFORM_TFSTATE} -var-file="${TERRAFORM_TFVARS}"

## terraform get
get: ; terraform get

## generate variables
init: ${TERRAFORM_TFVARS}

## terraform plan
plan: get init
	terraform validate
	@echo "${GREEN}✓ terraform validate - success${NC}"
	terraform plan -var-file="${TERRAFORM_TFVARS}" -state="${TERRAFORM_TFSTATE}" -out="${TERRAFORM_TFPLAN}"

## terraform show
show: ; terraform show "${TERRAFORM_TFSTATE}"

kubeconfig:
	@cat ${DIR_TMP}/kubeconfig

.PHONY: apply destroy get init module.% plan show
