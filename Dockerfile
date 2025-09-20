# --- Build Stage ---
FROM golang:1.21-alpine AS build

LABEL org.opencontainers.image.authors="almir@dzinovic.net"

WORKDIR /go/src/github.com/adnanh/webhook
ENV WEBHOOK_VERSION=2.8.2

# Install dependencies, download source, build webhook binary and remove build dependencies
RUN apk add --no-cache --virtual .build-deps curl gcc libc-dev git \
    && curl -L --silent -o webhook.tar.gz https://github.com/adnanh/webhook/archive/${WEBHOOK_VERSION}.tar.gz \
    && tar -xzf webhook.tar.gz --strip 1 \
    && go mod download \
    && CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/webhook \
    && apk del .build-deps

# --- Final Stage ---
FROM alpine:3.21

# Install runtime dependencies
RUN apk add --no-cache bash ca-certificates tzdata gettext git openssh docker docker-compose jq

COPY --from=build /usr/local/bin/webhook /usr/local/bin/webhook

WORKDIR /etc/webhook
VOLUME ["/etc/webhook"]
EXPOSE 9000

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
