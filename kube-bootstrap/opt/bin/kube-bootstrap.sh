#! /bin/bash
set -eo pipefail

types=(
    "clusterrole:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterroles"
    "clusterrolebinding:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterrolebindings"
    "serviceaccount:http://localhost:8080/api/v1/namespaces/kube-system/serviceaccounts"
    "configmap:http://localhost:8080/api/v1/namespaces/kube-system/configmaps"
    "daemonset:http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
)

vars='${VAULT_ADDR} ${KUBE_FQDN} ${ETCD_INITIAL_CLUSTER} ${ETCD_PKI_MOUNT} ${KUBE_PKI_MOUNT} ${SVC_ACCT_PUBKEY} ${SVC_ACCT_PRIVKEY} ${HYPERKUBE}'

opts="-sSfk --resolve kubernetes:443:127.0.0.1"
json="Content-Type: application/json"
auth="Authorization: Bearer bootstrap"
ds_api=http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets
bootstrap_manifests=/etc/kube-bootstrap/manifests

if [ ! $(curl $opts http://localhost:8080/healthz) ]; then
    echo "copying bootstrap manifests to /etc/kubernetes/manifests..."

    for item in $bootstrap_manifests/*; do
        cat $item | envsubst "$vars" > /etc/kubernetes/manifests/${item#$bootstrap_manifests}
    done
else
    echo "apiserver up already, not copying bootstrap manifests"
fi

until curl $opts -H "$auth" http://localhost:8080/healthz; do
    echo "waiting for apiserver..."; sleep 5;
done

echo ""
echo "apiserver ready"

api_objects=/etc/kube-bootstrap/api-objects
for entry in ${types[@]}; do
    api_type="${entry%%:*}"
    api_path="${entry#*:}"

    for file in $api_objects/$api_type.*.json; do
        echo ""
        echo "creating $api_type from $file"
        cat $file | envsubst "$vars" | curl $opts -H "$auth" -XPOST -H "$json" -d@- $api_path || true
    done
done

echo ""
echo "waiting for daemonsets to schedule"
for ds in $bootstrap_manifests/*.yaml; do
    ds_name=$(echo $ds | sed -e s,$bootstrap_manifests/,,g -e s,.yaml,,g -e s,bootstrap-,,g)

    echo "checking daemonset $ds_name"
    until [ $(curl $opts -H "$auth" $ds_api/$ds_name | jq .status.currentNumberScheduled) -gt 0 ]; do
        echo "waiting for $ds_name to schedule"; sleep 5;
    done
done

echo ""
echo "all daemonsets scheduled"

sleep 30
echo "deleting bootstrap components"
for bs in /etc/kubernetes/manifests/bootstrap-*.yaml; do
    echo "removing $bs"
    rm -f $bs
done

echo "sleeping forever..."
while true; do sleep 3600; done
