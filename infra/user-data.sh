#!/bin/bash
set -Eeuo pipefail
exec > >(tee -a /var/log/b3-1-bootstrap.log) 2>&1
trap 'echo "BOOTSTRAP_FAILED line=$LINENO time=$(date -Is)"' ERR
echo "BOOTSTRAP_STARTED $(date -Is)"
dnf install -y nginx
cat > /etc/nginx/nginx.conf <<'NGINX'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format evidence '$time_iso8601 client=$remote_addr request="$request" status=$status bytes=$body_bytes_sent duration=$request_time';
    access_log /var/log/nginx/access.log evidence;
    sendfile on;
    server {
        listen 80 default_server;
        server_name _;
        root /usr/share/nginx/html;
        location / { try_files $uri $uri/ =404; }
        location = /health {
            default_type text/plain;
            add_header Cache-Control "no-store";
            return 200 "OK\n";
        }
    }
}
NGINX
cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>B3-1 | Hello Cloud</title>
<style>body{font:18px system-ui;background:#f5f7fb;color:#14243b;max-width:720px;margin:12vh auto;padding:32px}main{background:white;border:1px solid #d7e0ed;border-radius:20px;padding:40px}small{color:#2563eb}a{color:#087f68}</style>
<main><small>AWS / SEOUL / B3-1</small><h1>Hello Cloud</h1><p>This page is served by Nginx on Amazon EC2.</p><p><a href="/health">Health check</a></p></main></html>
HTML
nginx -t
systemctl enable nginx
systemctl restart nginx
systemctl is-active nginx
curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 http://localhost/health
echo "BOOTSTRAP_COMPLETED $(date -Is)"
