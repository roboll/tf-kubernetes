#! /bin/bash
set -eo pipefail

vars='${VAULT_ADDR} ${KUBE_FQDN} ${ETCD_INITIAL_CLUSTER} ${ETCD_PKI_MOUNT} ${KUBE_PKI_MOUNT} ${SVC_ACCT_PUBKEY} ${SVC_ACCT_PRIVKEY} ${HYPERKUBE}'

cat /etc/kube-bootstrap/bootstrap.yaml | envsubst "$vars" > /etc/kubernetes/manifests/bootstrap.yaml
cat /etc/kube-bootstrap/kubeconfig.yaml | envsubst "$vars" > /etc/kubernetes/kubeconfig.yaml
