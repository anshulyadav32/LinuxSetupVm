#!/bin/bash

setup_domain_ssl() {
  echo "🔐 Trying Let's Encrypt SSL for domain(s)..."
  if ! command -v certbot >/dev/null; then
    sudo apt update
    sudo apt install -y certbot
  fi

  DOMAIN_ARGS="-d $HOST1"
  [[ -n "$HOST2" ]] && DOMAIN_ARGS="$DOMAIN_ARGS -d $HOST2"

  if sudo lsof -i:80 >/dev/null 2>&1; then
    echo "⚠️ Port 80 is in use. Switching to webroot mode."
    handle_certbot_webroot "$DOMAIN_ARGS"
  else
    echo "ℹ️ Port 80 is free. Using standalone mode."
    handle_certbot_standalone "$DOMAIN_ARGS"
  fi
}

handle_certbot_webroot() {
  if systemctl is-active --quiet apache2; then
    WEBROOT="/var/www/html"
  elif systemctl is-active --quiet nginx; then
    WEBROOT="/usr/share/nginx/html"
  else
    WEBROOT="/var/www/html"
  fi

  sudo mkdir -p "$WEBROOT"
  if sudo certbot certonly --webroot -w "$WEBROOT" "$1" --non-interactive --agree-tos -m admin@"$HOST1" --quiet; then
    echo "✅ SSL issued with webroot mode for $HOST1"
    CERT_PATH="/etc/letsencrypt/live/$HOST1"
    SSL_TYPE="Let's Encrypt (webroot)"
  else
    echo "❌ Let's Encrypt webroot mode failed."
    SSL_TYPE="Self-signed"
    USE_LE_SSL="no"
  fi
}

handle_certbot_standalone() {
  if sudo certbot certonly --standalone "$1" --non-interactive --agree-tos -m admin@"$HOST1" --quiet; then
    echo "✅ SSL issued with standalone mode for $HOST1"
    CERT_PATH="/etc/letsencrypt/live/$HOST1"
    SSL_TYPE="Let's Encrypt (standalone)"
  else
    echo "❌ Let's Encrypt standalone mode failed."
    SSL_TYPE="Self-signed"
    USE_LE_SSL="no"
  fi
}

generate_ssl() {
  echo "🔐 Generating self-signed SSL certificate..."
  sudo mkdir -p "$SSL_DIR"
  CN_VALUE="$HOST1"
  sudo openssl req -new -x509 -days 365 -nodes \
    -out "$SSL_DIR/server.crt" -keyout "$SSL_DIR/server.key" \
    -subj "/CN=$CN_VALUE" >/dev/null 2>&1

  sudo chmod 600 "$SSL_DIR/server.key"
  sudo chown postgres:postgres "$SSL_DIR/server.key" "$SSL_DIR/server.crt"
}
