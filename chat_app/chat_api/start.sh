#!/bin/bash
set -e

# =========================================================
# Laravel API service only
# Reverb now runs in a separate Railway service.
# =========================================================

# 1. Clear Laravel cached configuration
php artisan config:clear
php artisan cache:clear

# Apply database changes before the API accepts requests.
php artisan migrate --force

# 2. Start Laravel HTTP API internally on port 8000
php artisan serve --host=0.0.0.0 --port=8000 &

# 3. Debug information
echo "--- DEBUG: contents of /var/www/html ---"
ls -la /var/www/html

echo "--- DEBUG: contents of /var/www/html/docker ---"
ls -la /var/www/html/docker 2>&1 || echo "docker/ directory does not exist"

echo "--- DEBUG: contents of /var/www/html/docker/nginx ---"
ls -la /var/www/html/docker/nginx 2>&1 || echo "docker/nginx/ directory does not exist"

echo "--- END DEBUG ---"

# 4. Railway exposes nginx using its dynamic $PORT.
envsubst '${PORT}' \
  < /var/www/html/docker/nginx/default.conf.template \
  > /etc/nginx/http.d/default.conf

# 5. Keep nginx running in foreground
exec nginx -g "daemon off;"
