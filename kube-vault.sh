#! /usr/bin/env bash
# Configure Environment for Kube Cluster

set -eo pipefail

which kubectl >/dev/null || {
    echo "error: kubectl is required; install kubectl and retry."
    exit 1
}

envname=$1
[[ -z $envname ]] && {
    echo "error: envname is required."
    exit 1
}

role=user
username=${2:-$(whoami).kube-users.local}
[[ $username == admin ]] && {
    role=admin
    kubectl config set contexts.kube-${envname}.namespace kube-system
}

tld=${TLD:-"YOUR-TLD-HERE"}
[[ -z $tld ]] && {
    echo "error: tld is not set."
    exit 1
}

kube_addr="https://kube.${envname}.${tld}"
kubedir=~/.kube/kube-${envname}
mkdir -p $kubedir

vault_addr=${VAULT_ADDR:-"https://vault.$tld"}

curl -sSf $CURL_OPTS $vault_addr/v1/${envname}-kube/ca/pem > $kubedir/ca.pem

json=$(vault write -format=json ${envname}-kube/issue/$role common_name=$username)
sed -re 's/.*"certificate": "([^"]*)".*/\1/g' -e 's/\\n/\n/g' > $kubedir/cert.pem <<<$json
sed -re 's/.*"private_key": "([^"]*)".*/\1/g' -e 's/\\n/\n/g' > $kubedir/privkey.pem <<<$json

kubectl config set clusters.kube-${envname}.server $kube_addr
kubectl config set clusters.kube-${envname}.certificate-authority $kubedir/ca.pem

kubectl config set users.kube-${envname}-${role}-cert.client-certificate $kubedir/cert.pem
kubectl config set users.kube-${envname}-${role}-cert.client-key $kubedir/privkey.pem

kubectl config set contexts.kube-${envname}.cluster kube-${envname}
kubectl config set contexts.kube-${envname}.user kube-${envname}-${role}-cert
kubectl config use-context kube-${envname}
