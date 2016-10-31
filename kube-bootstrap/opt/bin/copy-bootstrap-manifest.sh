#! /bin/bash
set -eo pipefail

vars='${KUBE_FQDN} ${HYPERKUBE} ${ETCD_PEERS} ${ETCD_NODES}'
cat /etc/kube-bootstrap/bootstrap.yaml | envsubst "$vars" > /etc/kubernetes/manifests/bootstrap.yaml
