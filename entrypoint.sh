#!/bin/sh
set -e

if [ -f /etc/webhook/hooks.tpl.json ]; then
  echo "Generating hooks.json from template..."
  envsubst < /etc/webhook/hooks.tpl.json > /etc/webhook/hooks.json
fi

exec /usr/local/bin/webhook "$@"
