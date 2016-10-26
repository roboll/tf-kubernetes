#! /bin/bash
set -eo pipefail

vars='${VAULT_ADDR} ${KUBE_FQDN} ${ETCD_INITIAL_CLUSTER} ${ETCD_PKI_MOUNT} ${KUBE_PKI_MOUNT} ${SVC_ACCT_PUBKEY} ${SVC_ACCT_PRIVKEY} ${HYPERKUBE}'

item=/etc/kube-bootstrap/kubelet.yaml
cat $item | envsubst "$vars" > /etc/kubernetes/manifests/kubelet.yaml
