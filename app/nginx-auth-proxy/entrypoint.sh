#!/bin/sh
set -eu

: "${BACKEND_URL:?BACKEND_URL environment variable is required}"
: "${BASIC_AUTH_USER:?BASIC_AUTH_USER environment variable is required}"
: "${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD environment variable is required}"

LISTEN_PORT=${LISTEN_PORT:-80}
SERVER_NAME=${SERVER_NAME:-_}
AUTH_REALM=${AUTH_REALM:-Restricted}
BACKEND_TIMEOUT=${BACKEND_TIMEOUT:-600}

htpasswd -bc /etc/nginx/.htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASSWORD"

export LISTEN_PORT SERVER_NAME AUTH_REALM BACKEND_URL BACKEND_TIMEOUT

envsubst '$LISTEN_PORT $SERVER_NAME $AUTH_REALM $BACKEND_URL $BACKEND_TIMEOUT' \
  < /etc/nginx/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
