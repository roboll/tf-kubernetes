#! /bin/bash
set -eo pipefail

cp /etc/kube-bootstrap/cni/* /etc/cni/net.d/

if [ $1 == "forever" ]; then
    echo "sleeping forever..."
    while true; do sleep 3600; done;
fi
