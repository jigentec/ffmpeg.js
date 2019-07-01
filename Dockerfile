FROM alpine:latest
MAINTAINER Pu-Chen Mao <mao@jigentec.com>

RUN apk add --update-cache curl ca-certificates
COPY flvmetrics /usr/bin/flvmetrics

ENTRYPOINT ["flvmetrics"]

