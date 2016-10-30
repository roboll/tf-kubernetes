#! /bin/bash
set -eo pipefail

type_apis=(
    "clusterrole:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterroles"
    "clusterrolebinding:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterrolebindings"
    "configmap:http://localhost:8080/api/v1/namespaces/kube-system/configmaps"
    "service:http://localhost:8080/api/v1/namespaces/kube-system/services"
    "secret:http://localhost:8080/api/v1/namespaces/kube-system/secrets"
    "serviceaccount:http://localhost:8080/api/v1/namespaces/kube-system/serviceaccounts"
    "deployment:http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/deployments"
    "daemonset:http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
)
ds_api="http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
node_api="http://localhost:8080/api/v1/nodes"
healthz_api="http://localhost:8080/healthz"

vars='${VAULT_ADDR} ${KUBE_FQDN} ${ETCD_INITIAL_CLUSTER} ${ETCD_PKI_MOUNT} ${KUBE_PKI_MOUNT} ${SVC_ACCT_PUBKEY} ${SVC_ACCT_PRIVKEY} ${HYPERKUBE}'

opts="-sSfk --resolve kubernetes:443:127.0.0.1"
json="Content-Type: application/json"
auth="Authorization: Bearer bootstrap"
manifests=/etc/kube-bootstrap/manifests
api_objects=/etc/kube-bootstrap/api-objects

bootstrap() {
    if [ $(curl $opts $healthz_api) ] && [ curl $opts $node_api >/dev/null ]; then
        echo "apiserver up, not copying bootstrap manifests"
    else
        echo "copying bootstrap manifests to /etc/kubernetes/manifests..."

        for item in $manifests/*; do
            cat $item | envsubst "$vars" > /etc/kubernetes/manifests/${item#$manifests}
        done

        until curl $opts -H "$auth" $healthz_api; do
            echo "waiting for apiserver..."; sleep 5;
        done
    fi

    echo "apiserver ready"

    for entry in ${type_apis[@]}; do
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
    for ds in $manifests/*.yaml; do
        ds_name=$(echo $ds | sed -e s,$manifests/,,g -e s,.yaml,,g -e s,bootstrap-,,g)

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
}

bootstrap

while true; do
    sleep 60
    if [ $(curl $opts $healthz_api) ] && [ $(curl $opts $node_api) >/dev/null ]; then
        echo "apiserver ok, sleeping 60s"
    else
        bootstrap
    fi
done
