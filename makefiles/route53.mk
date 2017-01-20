test-route53: .tfstate
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} \
		"( nslookup etcd.${STATE_INTERNAL_TLD} )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} \
		"( dig ${STATE_INTERNAL_TLD} ANY )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} \
	  "( dig +noall +answer SRV _etcd-server._tcp.${STATE_INTERNAL_TLD} )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} \
		"( dig +noall +answer SRV _etcd-client._tcp.${STATE_INTERNAL_TLD} )"
	@scripts/ssh ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem ${STATE_BASTION_IP} \
		"( dig +noall +answer etcd.${STATE_INTERNAL_TLD} )"

.PHONY: test-route53
