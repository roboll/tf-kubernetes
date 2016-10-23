PREFIX  := quay.io/roboll
TAG     := $(shell git describe --tags --abbrev=0 HEAD)

image:
	./images/kube-bootstrap/yaml2json.sh
	docker build -t ${PREFIX}/kube-bootstrap:${TAG} images/kube-bootstrap
.PHONY: images

push: image
	docker push ${PREFIX}/kube-bootstrap:${TAG}
.PHONY: push
