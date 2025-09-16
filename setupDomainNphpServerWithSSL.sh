#!/bin/bash
# ============================================================
# Setup a Domain with Nginx + SSL + Readiness Check
# Author: Anshul Yadav
# ============================================================

set -e

# ===== Input =====
read -p "Enter domain name (e.g., mysite.example.com): " DOMAIN
DOMAIN=${DOMAIN,,} # lowercase

WEBROOT="/var/www/$DOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

if [[ -z "$DOMAIN" ]]; then
  echo "❌ Domain name cannot be empty!"
  exit 1
fi

# ===== Install Dependencies =====
echo "📦 Installing Nginx + Certbot..."
sudo apt-get update -y
sudo apt-get install -y nginx certbot python3-certbot-nginx curl

# ===== Setup Web Root =====
echo "🌐 Creating web root at $WEBROOT ..."
sudo mkdir -p "$WEBROOT"

cat > /tmp/index.html <<HTML
<!DOCTYPE html>
<html>
<head>
  <title>$DOMAIN</title>
  <style>
    body { font-family: Arial; text-align: center; padding: 80px; }
    h1 { color: #2c3e50; }
    p { color: #16a085; }
  </style>
</head>
<body>
  <h1>Welcome to $DOMAIN 🎉</h1>
  <p>This domain is ready and secured with SSL 🔒</p>
</body>
</html>
HTML

sudo mv /tmp/index.html "$WEBROOT/index.html"

# ===== Configure Nginx =====
echo "⚙️ Configuring Nginx for $DOMAIN ..."
sudo bash -c "cat > $NGINX_CONF" <<NGINXCONF
server {
    listen 80;
    server_name $DOMAIN;

    root $WEBROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINXCONF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/$DOMAIN
sudo rm -f /etc/nginx/sites-enabled/default

# ===== Reload Nginx =====
sudo nginx -t && sudo systemctl restart nginx

# ===== Setup SSL =====
echo "🔒 Requesting SSL certificate for $DOMAIN ..."
if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN; then
  echo "✅ SSL issued for $DOMAIN"
else
  echo "❌ Failed to issue SSL for $DOMAIN"
  exit 1
fi

# ===== Enable Auto Renewal =====
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# ===== Check Domain Reachability =====
echo "🌍 Checking if $DOMAIN is reachable..."
if curl -s --head "https://$DOMAIN" | grep "200 OK" >/dev/null; then
  echo "✅ $DOMAIN is ready and live with HTTPS!"
else
  echo "⚠️ $DOMAIN setup done, but it may take time for DNS to propagate."
fi

echo "📌 Test in browser: https://$DOMAIN"
