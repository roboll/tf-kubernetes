#! /bin/bash
set -eo pipefail

set -a
if [ -f /etc/kube-bootstrap/env ]; then . /etc/kube-bootstrap/env; fi;
cat /etc/kube-bootstrap/bootstrap.yaml | envsubst > /etc/kubernetes/manifests/bootstrap.yaml
