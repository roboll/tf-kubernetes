#! /bin/bash
set -eo pipefail

if [ ! -x $(which yaml2json) ]; then
    go get -u github.com/bronze1man/yaml2json
fi

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src=$dir/etc/kube-bootstrap/api-objects/src
dest=$dir/etc/kube-bootstrap/api-objects

rm -f $dest/*.json
for file in $src/*.yaml; do
    cat $file | yaml2json > $(echo $file | sed -e s/yaml/json/g -e "s,$src,$dest,g");
done
