PREFIX  := quay.io/roboll
TAG     := $(shell git describe --tags --abbrev=0 HEAD)

clean:
	rm -r ./kube-bootstrap/etc/kube-bootstrap/api-objects

image:
	./kube-bootstrap/yaml2json.sh
	docker build -t ${PREFIX}/kube-bootstrap:${TAG} kube-bootstrap
.PHONY: images

push: image
	docker push ${PREFIX}/kube-bootstrap:${TAG}
.PHONY: push
