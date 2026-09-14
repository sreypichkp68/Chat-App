#!/bin/bash
set -e

# 1. Start Reverb (websocket server) on an internal-only port.
php artisan reverb:start --host=0.0.0.0 --port=8080 &

# 2. Start the normal Laravel HTTP server on another internal-only port.
php artisan serve --host=0.0.0.0 --port=8000 &

# 3. Render the nginx config, substituting Railway's dynamic $PORT.
#    nginx becomes the single process Railway's public domain actually
#    talks to, and it routes requests to whichever internal process
#    should handle them (Reverb vs artisan serve) based on the path.
echo "--- DEBUG: contents of /var/www/html ---"
ls -la /var/www/html
echo "--- DEBUG: contents of /var/www/html/docker ---"
ls -la /var/www/html/docker 2>&1 || echo "docker/ directory does not exist"
echo "--- DEBUG: contents of /var/www/html/docker/nginx ---"
ls -la /var/www/html/docker/nginx 2>&1 || echo "docker/nginx/ directory does not exist"
echo "--- END DEBUG ---"

envsubst '${PORT}' < /var/www/html/docker/nginx/default.conf.template > /etc/nginx/http.d/default.conf

# 4. Run nginx in the foreground so the container has a long-lived
#    process that Railway considers "alive". If nginx exits, the
#    container stops — which is what we want if something goes wrong.
nginx -g "daemon off;"