#! /bin/bash
set -eo pipefail

vars='${KUBE_FQDN} ${CERT_PATH}'
cat /etc/kubernetes/kubeconfig.yaml | envsubst "$vars" > /etc/kubeconfig/kubeconfig.yaml

if [ $1 == "forever" ]; then
    echo "sleeping forever..."
    while true; do sleep 3600; done;
fi
