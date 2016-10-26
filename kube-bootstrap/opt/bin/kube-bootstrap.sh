#! /bin/bash
set -eo pipefail

types=(
    "serviceaccount:api/v1/namespaces/kube-system/serviceaccounts"
    "configmap:api/v1/namespaces/kube-system/configmaps"
    "clusterrole:apis/rbac.authorization.k8s.io/v1alpha1/clusterroles"
    "clusterrolebinding:apis/rbac.authorization.k8s.io/v1alpha1/clusterrolebindings"
    "daemonset:apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
)

vars='${VAULT_ADDR} ${KUBE_FQDN} ${ETCD_INITIAL_CLUSTER} ${ETCD_PKI_MOUNT} ${KUBE_PKI_MOUNT} ${SVC_ACCT_PUBKEY} ${SVC_ACCT_PRIVKEY} ${HYPERKUBE}'

echo "copying bootstrap manifests to /etc/kubernetes/manifests..."
dir=/etc/kube-bootstrap/manifests
for item in $dir/*; do
    cat $item | envsubst "$vars" > /etc/kubernetes/manifests/${item#$dir}
done

key=/etc/secrets/bootstrap.key
cert=/etc/secrets/bootstrap.crt
cacert=/etc/secrets/bootstrap.ca

[ -f $key ] && [ -f $cert ] && [ -f $cacert ] || {
    echo "tls credentials not found"
    exit 1
}

#opts="-sSf --resolve kubernetes:443:127.0.0.1 --key $key --cert $cert --cacert $cacert"
opts="-sSf"

until curl $opts http://kubernetes/healthz; do
    echo "waiting for apiserver..."; sleep 5;
done

echo ""
echo "apiserver ready"

api_objects=/etc/kube-bootstrap/api-objects
for entry in ${types[@]}; do
    api_type="${entry%%:*}"
    api_path="${entry#*:}"

    for file in $api_objects/$api_type.*.json; do
        marker=$(echo $file | sed s,$api_objects,/markers,g).created
        if [ ! -f ${marker} ]; then
            echo ""
            echo "creating $api_type from $file"
            cat $file | envsubst "$vars" | \
                curl $opts -XPOST -H "Content-Type: application/json" -d@- http://kubernetes/$api_path
            touch ${marker}
        else
            echo ""
            echo "$file exists, not creating $api_type"
        fi
    done
done

echo ""
echo "copying kubelet to manifests dir"
cat /etc/kube-bootstrap/kubelet-controller.yaml | envsubst "$vars" > /etc/kubernetes/manifests/kubelet.yaml

echo ""
echo "waiting for daemonsets to schedule"
manifests=/etc/kube-bootstrap/manifests
ds_api_path=apis/extensions/v1beta1/namespaces/kube-system/daemonsets
for ds in $manifests/*.yaml; do
    ds_name=$(echo $ds | sed -e s,$manifests/,,g -e s,.yaml,,g -e s,bootstrap-,,g)
    echo "checking daemonset $ds_name"
    until [ $(curl $opts http://kubernetes/$ds_api_path/$ds_name | jq .status.currentNumberScheduled) -gt 0 ]; do
        echo "waiting for $ds_name to schedule"; sleep 5;
    done
    rm -f etc/kubernetes/manifests/bootstrap-$ds_name.yaml
done

echo ""
echo "TODO: need to move kubelet to daemonset"

echo "sleeping forever..."
while true; do sleep 3600; done
