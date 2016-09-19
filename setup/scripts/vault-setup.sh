#! /usr/bin/env bash
set -eo pipefail

vault_role="${approle}"

kube_name="${name}"
kube_namespace="${namespace}"

role_id="$(vault read -field=role_id auth/approle/role/$vault_role/role-id)"
kubectl create configmap vault-role-$kube_name --namespace=$kube_namespace \
    --from-literal=role-name=$vault_role --from-literal=role-id=$role_id

secret_id="$(vault write -f -field=secret_id auth/approle/role/$vault_role/secret-id)"
kubectl create secret generic vault-secret-$kube_name --namespace=$kube_namespace \
    --from-literal=secret-id=$secret_id
