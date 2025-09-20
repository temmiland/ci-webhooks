FROM        golang:alpine AS build
LABEL       org.opencontainers.image.authors="almir@dzinovic.net"

WORKDIR     /go/src/github.com/adnanh/webhook
ENV         WEBHOOK_VERSION=2.8.2

RUN apk add --update -t build-deps curl libc-dev gcc libgcc \
 && curl -L --silent -o webhook.tar.gz https://github.com/adnanh/webhook/archive/${WEBHOOK_VERSION}.tar.gz \
 && tar -xzf webhook.tar.gz --strip 1 \
 && go mod download \
 && CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/webhook

FROM        alpine:latest

RUN apk --no-cache add git openssh docker docker-compose bash jq ca-certificates tzdata

COPY --from=build /usr/local/bin/webhook /usr/local/bin/webhook

WORKDIR     /etc/webhook
VOLUME      ["/etc/webhook"]
EXPOSE      9000

ENTRYPOINT  ["/usr/local/bin/webhook"]
