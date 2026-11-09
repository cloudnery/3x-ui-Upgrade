#!/bin/bash
set -e

echo "🚀 Starting X-UI + nginx reverse proxy..."
export NGINX_PORT=3000

# Root filesystem is read-only on this platform -> find a writable dir
RT=""
for d in /tmp /dev/shm /var/tmp /run; do
  if mkdir -p "$d/xui-rt" 2>/dev/null && touch "$d/xui-rt/.w" 2>/dev/null; then
    rm -f "$d/xui-rt/.w"
    RT="$d/xui-rt"
    break
  fi
done
if [ -z "$RT" ]; then
  echo "❌ No writable directory found. Mounts:"
  mount | head -30 || true
  exit 1
fi
echo "✅ Using writable dir: $RT"
export RT

mkdir -p "$RT/db" "$RT/log" "$RT/bin" "$RT/nginx"
export XUI_DB_FOLDER="$RT/db"
export XUI_LOG_FOLDER="$RT/log"
export XUI_BIN_FOLDER="$RT/bin"

# xray binary + geo files stay in the image (symlinks); config.json must be writable (copy)
for f in /usr/local/x-ui/bin/*; do
  b=$(basename "$f")
  if [ "$b" = "config.json" ]; then cp -f "$f" "$RT/bin/$b"; else ln -sf "$f" "$RT/bin/$b"; fi
done

cd /usr/local/x-ui

echo "🔧 Applying panel settings via x-ui CLI..."
./x-ui setting -port 2053 -webBasePath /managepanel/ || echo "⚠️ x-ui setting failed (continuing)"

echo "🔧 Building nginx.conf for fixed port: $NGINX_PORT"
envsubst '${NGINX_PORT} ${RT}' < /etc/nginx/nginx.conf.template > "$RT/nginx/nginx.conf"
nginx -e /dev/stderr -c "$RT/nginx/nginx.conf" -t

echo "▶️  Starting x-ui in background..."
./x-ui &
XUI_PID=$!

sleep 2
if ! kill -0 "$XUI_PID" 2>/dev/null; then
  echo "❌ x-ui exited right after start (see messages above)"
fi

echo "▶️  Starting nginx in foreground on port $NGINX_PORT..."
exec nginx -e /dev/stderr -c "$RT/nginx/nginx.conf" -g "daemon off;"
