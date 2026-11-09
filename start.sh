#!/bin/bash
set -e

echo "🚀 Starting X-UI + nginx reverse proxy..."

export NGINX_PORT=3000
export XUI_DB_FOLDER=/etc/x-ui
export XUI_LOG_FOLDER=/var/log/x-ui

# Recreate at runtime: a platform volume/overlay can hide dirs created at build time
mkdir -p "$XUI_DB_FOLDER" "$XUI_LOG_FOLDER"

echo "🔎 user id: $(id -u)"
ls -ld "$XUI_DB_FOLDER" || true
if touch "$XUI_DB_FOLDER/.write-test" 2>/dev/null; then
  rm -f "$XUI_DB_FOLDER/.write-test"
  echo "✅ db dir is writable"
else
  echo "❌ db dir is NOT writable"
fi

cd /usr/local/x-ui

echo "🔧 Applying panel settings via x-ui CLI..."
./x-ui setting -port 2053 -webBasePath /managepanel/ || echo "⚠️ x-ui setting failed (continuing)"

echo "🔧 Building nginx.conf for fixed port: $NGINX_PORT"
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t

echo "▶️  Starting x-ui in background..."
./x-ui &
XUI_PID=$!

sleep 2
if ! kill -0 "$XUI_PID" 2>/dev/null; then
  echo "❌ x-ui exited right after start (see messages above)"
fi

echo "▶️  Starting nginx in foreground on port $NGINX_PORT..."
exec nginx -g "daemon off;"
