FROM golang:1.6-alpine

ADD . /go/src/etcd-metrics-proxy/

RUN go install etcd-metrics-proxy

ENTRYPOINT [ "/go/bin/etcd-metrics-proxy" ]
