FROM alpine:3.21

# Runtime dependencies for the deploy agent: git for repo updates, docker-cli/docker-cli-compose
# for the per-repo deploy scripts, jq for repos.json lookups.
RUN apk add --no-cache bash ca-certificates tzdata git openssh docker-cli docker-cli-compose jq

# The projects volume is bind-mounted from the host and owned by the host user,
# so git (running as root here) refuses it as a foreign directory without this.
RUN git config --system --add safe.directory '*'

WORKDIR /opt/webhook

ENTRYPOINT ["bash", "/opt/webhook/watch.sh"]
