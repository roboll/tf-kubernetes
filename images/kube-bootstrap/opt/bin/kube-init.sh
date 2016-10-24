#! /bin/bash
set -eo pipefail

types=(
    "clusterrole:apis/rbac.authorization.k8s.io/v1alpha1/clusterroles"
    "clusterrolebinding:apis/rbac.authorization.k8s.io/v1alpha1/clusterrolebindings"
    "daemonset:apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
    "configmap:api/v1/namespaces/kube-system/configmaps"
)

key=/etc/secrets/bootstrap.key
cert=/etc/secrets/bootstrap.crt
cacert=/etc/secrets/bootstrap.ca

[ -f $key ] && [ -f $cert ] && [ -f $cacert ] || {
    echo "tls credentials not found"
    exit 1
}

opts="-sSf --resolve kubernetes:443:127.0.0.1 --key $key --cert $cert --cacert $cacert"

until curl $opts https://kubernetes/healthz; do
    echo "waiting for apiserver..."; sleep 5;
done

echo ""
echo "apiserver ready"

vars='${VAULT_ADDR} ${KUBE_FQDN} ${ETCD_INITIAL_CLUSTER} ${ETCD_PKI_MOUNT} ${KUBE_PKI_MOUNT} ${SVC_ACCT_PUBKEY} ${SVC_ACCT_PRIVKEY} ${HYPERKUBE}'

dir=/etc/kubernetes/bootstrap/api-objects
for entry in ${types[@]}; do
    apitype="${entry%%:*}"
    apipath="${entry#*:}"

    for file in $dir/$apitype.*.json; do
        marker=$(echo $file | sed s,$dir,/markers,g).created
        if [ ! -f ${marker} ]; then
            echo ""
            echo "creating $apitype from $file"
            cat $file | envsubst "$vars" | \
                curl $opts -XPOST -H "Content-Type: application/json" -d@- https://kubernetes/$apipath
            touch ${marker}
        else
            echo ""
            echo "$file exists, not creating $apitype"
        fi
    done
done

echo "copying kubelet to manifests dir"
cat /etc/kubernetes/kubelet-controller.yaml | envsubst "$vars" > /etc/kubernetes/manifests/kubelet.yaml
trap "rm -f /etc/kubernetes/manifests/kubelet.yaml" EXIT

echo "sleeping forever..."
while true; do sleep 3600; done
