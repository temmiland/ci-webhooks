#!/bin/sh
set -e

# An empty CI_KEY would render `"value": ""` into hooks.json and effectively
# disable authentication — refuse to start instead.
if [ -z "${CI_KEY:-}" ] || [ "$CI_KEY" = "null" ]; then
  echo "ERROR: CI_KEY is not set — refusing to start with an empty API key." >&2
  exit 1
fi

# The key is substituted verbatim into JSON; restrict it to safe characters.
case "$CI_KEY" in
  *[!A-Za-z0-9_-]*)
    echo "ERROR: CI_KEY may only contain characters [A-Za-z0-9_-]." >&2
    exit 1
    ;;
esac

if [ -f /etc/webhook/hooks.tpl.json ]; then
  echo "Generating hooks.json from template..."
  envsubst < /etc/webhook/hooks.tpl.json > /etc/webhook/hooks.json
fi

exec /usr/local/bin/webhook "$@"
