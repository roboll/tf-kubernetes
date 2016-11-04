#! /bin/bash
set -eo pipefail

cat /etc/kube-bootstrap/vault-cert-sidecar.yaml | envsubst > /etc/kubernetes/manifests/vault-cert-sidecar.yaml
