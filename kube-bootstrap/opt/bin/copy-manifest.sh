#! /bin/bash
set -eo pipefail

vars='${KUBE_FQDN} ${KUBE_CA} ${HYPERKUBE} ${ETCD_PEERS} ${ETCD_NODES}'
cat /etc/kube-bootstrap/bootstrap.yaml | envsubst "$vars" > /etc/kubernetes/manifests/bootstrap.yaml
