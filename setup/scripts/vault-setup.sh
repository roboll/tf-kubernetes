#! /usr/bin/env bash

#TODO check for vault and kubectl binaries

role="${approle}"
namespace="${namespace}"

role_id="$(vault read -field=role_id auth/approle/role/$role/role-id)"
kubectl create configmap $${role}-vault-role --namespace=kube-system \
    --from-literal-value=role_id=$role_id

secret_id="$(vault write -f -field=secret_id auth/approle/role/$role/secret-id)"
kubectl create secret generic $${role}-vault-secret \
    --from-literal-value=secret_id=$secret_id --namespace=kube-system
