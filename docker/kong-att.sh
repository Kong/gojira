#!/usr/bin/env sh

hash nginx 2> /dev/null && ngx='nginx'
ngx=${ngx:-"/usr/local/openresty/nginx/sbin/nginx"}

export KONG_NGINX_DAEMON=off
kong prepare -p "$KONG_PREFIX" "$@"

ln -sf /dev/stdout "$KONG_PREFIX/logs/access.log"
ln -sf /dev/stdout "$KONG_PREFIX/logs/admin_access.log"
ln -sf /dev/stderr "$KONG_PREFIX/logs/error.log"

exec $ngx -p "$KONG_PREFIX" -c nginx.conf
