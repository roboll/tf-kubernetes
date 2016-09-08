FROM golang:1.6-alpine

ADD . /go/src/podmaster/

RUN go install podmaster

ENTRYPOINT [ "/go/bin/podmaster" ]
