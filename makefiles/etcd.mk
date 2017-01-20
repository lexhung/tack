test-etcd: .tfstate
	ssh -A core@${STATE_BASTION_IP} \
		'( curl -s http://etcd.${STATE_INTERNAL_TLD}:2379/version )' \
		| grep '{"etcdserver":"2.3.2","etcdcluster":"2.3.0"}'
	ssh -A core@${STATE_BASTION_IP} \
		'( curl -s http://etcd.${STATE_INTERNAL_TLD}:2379/health )' \
		| grep '{"health": "true"}'
	ssh -A core@${STATE_BASTION_IP} \
		'( curl -s http://etcd.${STATE_INTERNAL_TLD}:2379/v2/members )' \
		| grep -o '"name":' | wc -l | grep 3

.PHONY: test-etcd
