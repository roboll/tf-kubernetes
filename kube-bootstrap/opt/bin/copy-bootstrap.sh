#! /bin/bash
set -eo pipefail

cat /etc/kube-bootstrap/bootstrap.yaml | envsubst > /etc/kubernetes/manifests/bootstrap.yaml
