#! /bin/bash
set -eo pipefail

kube_apis=(
    "clusterrole:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterroles"
    "clusterrolebinding:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterrolebindings"
    "thirdpartyresource:http://localhost:8080/apis/extensions/v1beta1/thirdpartyresources"
    "serviceaccount:http://localhost:8080/api/v1/namespaces/kube-system/serviceaccounts"
    "configmap:http://localhost:8080/api/v1/namespaces/kube-system/configmaps"
    "secret:http://localhost:8080/api/v1/namespaces/kube-system/secrets"
    "deployment:http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/deployments"
    "daemonset:http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
    "service:http://localhost:8080/api/v1/namespaces/kube-system/services"
    "secretclaim:http://localhost:8080/apis/vaultproject.io/v1/namespaces/kube-system/secretclaims"
)
kube_ds_api="http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
kube_node_api="http://localhost:8080/api/v1/nodes"
kube_healthz_api="http://localhost:8080/healthz"

curl_kube_opts="-sSfk --resolve kubernetes:443:127.0.0.1"
curl_kube_auth="Authorization: Bearer bootstrap"

curl_vault_opts="-sSf"

curl_json="Content-Type: application/json"

manifest_path=/etc/kube-bootstrap/manifests
objects_path=/etc/kube-bootstrap/api/objects

bootstrap() {
    if curl $curl_kube_opts $kube_healthz_api >/dev/null && \
        curl $curl_kube_opts $kube_node_api >/dev/null; then
        echo "apiserver up, not copying bootstrap manifests"
    else
        echo "copying bootstrap manifests to /etc/kubernetes/manifests..."

        for item in $manifest_path/*; do
            cat $item | envsubst > /etc/kubernetes/manifests/${item#$manifest_path}
        done

        until curl $curl_kube_opts -H "$curl_kube_auth" $kube_healthz_api; do
            echo "waiting for bootstrap apiserver (5s)..."; sleep 5;
        done
    fi

    echo ""
    echo "apiserver ready, applying manifests"
    for entry in ${kube_apis[@]}; do
        api_type="${entry%%:*}"
        api_path="${entry#*:}"

        for file in $objects_path/$api_type.*.json; do
            echo "creating $api_type from $file"
            cat $file | envsubst | curl $curl_kube_opts -XPOST \
                -H "$curl_kube_auth" -H "$curl_json" -d@- $api_path || true
            sleep .5
        done
    done

    echo ""
    echo "waiting for daemonsets to schedule"
    for ds in $manifest_path/bootstrap-ds-*.yaml; do
        ds_name=$(echo $ds | sed -e s,$manifest_path/,,g -e s,.yaml,,g -e s,bootstrap-ds-,,g)

        echo "checking daemonset $ds_name"
        until [ $(curl $curl_kube_opts -H "$curl_kube_auth" $kube_ds_api/$ds_name | \
            jq .status.currentNumberScheduled) -gt 0 ]; do
            echo "waiting for $ds_name to schedule"; sleep 5;
        done
    done

    echo ""
    echo "all daemonsets scheduled, deleting bootstrap components"
    for bs in /etc/kubernetes/manifests/bootstrap-*.yaml; do
        echo "removing $bs"
        rm -f $bs
    done

    echo "waiting 30s for bootstrap components to shut down"
    sleep 30

    echo "bootstrap complete"
}

load_env_file() {
    if [ -f /etc/kube-bootstrap/env ]; then
        set -a
        . /etc/kube-bootstrap/env
        set +a
    fi
}

download_ca_certs() {
    kube_ca_file=$(mktemp)
    curl $curl_vault_opts ${VAULT_ADDR}/v1/${KUBE_PKI_MOUNT}/ca/pem -o $kube_ca_file
    export KUBE_CA=$(base64 $kube_ca_file | tr -d '\n')

    etcd_ca_file=$(mktemp)
    curl $curl_vault_opts ${VAULT_ADDR}/v1/${ETCD_PKI_MOUNT}/ca/pem -o $etcd_ca_file
    export ETCD_CA=$(base64 $etcd_ca_file | tr -d '\n')
}

init() {
    load_env_file
    download_ca_certs
}

run() {
    while true; do
        if curl $curl_kube_opts $kube_healthz_api >/dev/null && \
            curl $curl_kube_opts $kube_node_api >/dev/null; then
        echo "apiserver ok..."
        else
            echo "apiserver down, running bootstrap sequence"
            bootstrap
            sleep 30
        fi

        sleep 10
    done
}

init
run
