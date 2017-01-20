test-route53:
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem `${CMD_BASTION_IP}` \
		"( nslookup etcd.`${CMD_INTERNAL_TLD}` )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem `${CMD_BASTION_IP}` \
		"( dig `${CMD_INTERNAL_TLD}` ANY )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem `${CMD_BASTION_IP}` \
	  "( dig +noall +answer SRV _etcd-server._tcp.`${CMD_INTERNAL_TLD}` )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem `${CMD_BASTION_IP}` \
		"( dig +noall +answer SRV _etcd-client._tcp.`${CMD_INTERNAL_TLD}` )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem `${CMD_BASTION_IP}` \
		"( dig +noall +answer etcd.`${CMD_INTERNAL_TLD}` )"

.PHONY: test-route53
