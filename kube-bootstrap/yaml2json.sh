#! /bin/bash
set -eo pipefail

if [ ! -x $(which yaml2json) ]; then
    go get -u github.com/bronze1man/yaml2json
fi

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src=$dir/etc/kube-bootstrap/api/src
dest=$dir/etc/kube-bootstrap/api/objects

rm -rf $dest
mkdir -p $dest

for file in $src/*.yaml; do
    cat $file | yaml2json > $(echo $file | sed -e s/yaml/json/g -e "s,$src,$dest,g");
done
