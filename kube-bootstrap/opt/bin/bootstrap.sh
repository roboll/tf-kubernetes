#! /bin/bash
set -eo pipefail

kube_apis=(
    "clusterrole:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterroles"
    "clusterrolebinding:https://kubernetes/apis/rbac.authorization.k8s.io/v1alpha1/clusterrolebindings"
    "configmap:http://localhost:8080/api/v1/namespaces/kube-system/configmaps"
    "daemonset:http://localhost:8080/apis/extensions/v1beta1/namespaces/kube-system/daemonsets"
    "secret:http://localhost:8080/api/v1/namespaces/kube-system/secrets"
    "service:http://localhost:8080/api/v1/namespaces/kube-system/services"
    "serviceaccount:http://localhost:8080/api/v1/namespaces/kube-system/serviceaccounts"
)
kube_pod_api="http://localhost:8080/api/v1/namespaces/kube-system/pods"
kube_node_api="http://localhost:8080/api/v1/nodes"
kube_healthz_api="http://localhost:8080/healthz"

curl_kube_opts="-sSfk --resolve kubernetes:443:127.0.0.1"
curl_kube_auth="Authorization: Bearer bootstrap"

curl_vault_opts="-sSf"

curl_json="Content-Type: application/json"

manifest_path=/etc/kube-bootstrap/manifests
objects_path=/etc/kube-bootstrap/api/objects

log() {
    echo "$(date '+%D %T') $@"
}

bootstrap() {
    if curl $curl_kube_opts $kube_healthz_api >/dev/null && \
        curl $curl_kube_opts $kube_node_api >/dev/null; then
        log "apiserver up, not copying bootstrap manifests"
    else
        log "copying bootstrap manifests to /etc/kubernetes/manifests..."

        for item in $manifest_path/*; do
            cat $item | envsubst > /etc/kubernetes/manifests/${item#$manifest_path}
        done

        until curl $curl_kube_opts -H "$curl_kube_auth" $kube_healthz_api; do
            log "waiting for bootstrap apiserver...";
            sleep 5
        done
    fi

    download_ca_certs
    download_svc_acct

    log "apiserver ready, applying manifests"
    for entry in ${kube_apis[@]}; do
        api_type="${entry%%:*}"
        api_path="${entry#*:}"

        for file in $objects_path/$api_type.*.json; do
            log "creating $api_type from $file"
            cat $file | \
                envsubst | \
                curl $curl_kube_opts -XPOST -H "$curl_kube_auth" -H "$curl_json" -d@- $api_path >/dev/null \
                || true
        done
    done

    log "waiting for critical daemonsets to schedule"
    for ds in {etcd,apiserver,proxy,controller-manager}; do
        ds_name=$(echo $ds | sed -e s,$manifest_path/,,g -e s,.yaml,,g -e s,bootstrap-,,g)

        log "checking daemonset $ds_name"
        until curl $curl_kube_opts -H "$curl_kube_auth" $kube_pod_api?labelSelector=app=$ds_name | \
            jq -er ".items[] | \
                    select(.status.phase == \"Running\") | \
                    select(.spec.nodeName == \"$(hostname -f)\")"; do
            log "waiting for $ds_name to schedule on $(hostname -f)"
            sleep 5
        done
    done

    log "critical daemonsets scheduled, deleting bootstrap components"
    for bootstrap in $manifest_path/*.yaml; do
        manifest=$(echo $bootstrap | sed s,kube-bootstrap,kubernetes,g)
        log "removing $manifest"
        rm -f $manifest
    done

    while curl $curl_kube_opts -H "$curl_kube_auth" $kube_pod_api?labelSelector=phase=bootstrap | \
        jq -er ".items[] | \
                select(.status.phase == \"Running\") | \
                select(.spec.nodeName == \"$(hostname -f)\") | \
                length as \$length | \$length > 0"; do
        log "waiting for bootstrap components to shut down"
        sleep 5
    done

    log "bootstrap complete"
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

download_svc_acct() {
    until [ -f /var/lib/vault/token ]; do
        log "waiting for vault token file..."
        sleep 5
    done
    VAULT_TOKEN=$(cat /var/lib/vault/token)

    privkey_file=$(mktemp)
    curl $curl_vault_opts -H "X-Vault-Token: $VAULT_TOKEN" ${VAULT_ADDR}/v1/${SVC_ACCT_PRIVKEY_PATH} -o $privkey_file
    export SVC_ACCT_PRIVKEY=$(jq -r '.data."privkey.pem"' $privkey_file | base64 | tr -d '\n')

    pubkey_file=$(mktemp)
    curl $curl_vault_opts -H "X-Vault-Token: $VAULT_TOKEN" ${VAULT_ADDR}/v1/${SVC_ACCT_PUBKEY_PATH} -o $pubkey_file
    export SVC_ACCT_PUBKEY=$(jq -r '.data."pubkey.pem"' $pubkey_file | base64 | tr -d '\n')
}

run() {
    while true; do
        if curl $curl_kube_opts $kube_healthz_api >/dev/null && \
            curl $curl_kube_opts $kube_node_api >/dev/null; then
        log "apiserver ok..."
        else
            log "apiserver down, running bootstrap sequence"
            bootstrap
            sleep 30
        fi

        sleep 10
    done
}

load_env_file
run
