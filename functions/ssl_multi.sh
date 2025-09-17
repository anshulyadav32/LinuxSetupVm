#!/bin/bash
# Function to setup SSL for Nginx, Apache, and PM2 apps
# Usage: setup_ssl_multi <domain> <webroot> <service> (service: nginx|apache|pm2)

setup_ssl_multi() {
  local DOMAIN="$1"
  local WEBROOT="$2"
  local SERVICE="$3"

  if [[ -z "$DOMAIN" || -z "$WEBROOT" || -z "$SERVICE" ]]; then
    echo "Usage: setup_ssl_multi <domain> <webroot> <service> (service: nginx|apache|pm2)"
    return 1
  fi

  if ! command -v certbot >/dev/null; then
    sudo apt update
    sudo apt install -y certbot
  fi

  if [[ "$SERVICE" == "nginx" ]]; then
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@"$DOMAIN" --redirect || return 1
    sudo systemctl reload nginx
    echo "✅ SSL enabled for $DOMAIN (nginx)"
  elif [[ "$SERVICE" == "apache" ]]; then
    sudo certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m admin@"$DOMAIN" --redirect || return 1
    sudo systemctl reload apache2
    echo "✅ SSL enabled for $DOMAIN (apache)"
  elif [[ "$SERVICE" == "pm2" ]]; then
    # For PM2, generate self-signed cert and print paths
    local SSL_DIR="$WEBROOT/ssl"
    sudo mkdir -p "$SSL_DIR"
    sudo openssl req -new -x509 -days 365 -nodes \
      -out "$SSL_DIR/server.crt" -keyout "$SSL_DIR/server.key" \
      -subj "/CN=$DOMAIN" >/dev/null 2>&1
    sudo chown $USER:$USER "$SSL_DIR/server.crt" "$SSL_DIR/server.key"
    echo "✅ Self-signed SSL generated for $DOMAIN (pm2)"
    echo "    Cert: $SSL_DIR/server.crt"
    echo "    Key:  $SSL_DIR/server.key"
  else
    echo "Unknown service: $SERVICE"
    return 1
  fi
}
