#!/bin/bash
# ============================================================
# Setup a Domain with Nginx + SSL + Readiness Check
# Author: Anshul Yadav
# ============================================================

set -e

# ===== Function to read the domain =====
read_domain() {
    read -p "Enter domain name (e.g., mysite.example.com): " DOMAIN
    DOMAIN=${DOMAIN,,} # lowercase

    if [[ -z "$DOMAIN" ]]; then
        echo "❌ Domain name cannot be empty!"
        exit 1
    fi
}

# ===== Function to install dependencies =====
install_dependencies() {
    echo "📦 Installing Nginx + Certbot..."
    sudo apt-get update -y
    sudo apt-get install -y nginx certbot python3-certbot-nginx curl
}

# ===== Function to setup web root =====
setup_web_root() {
    WEBROOT="/var/www/$DOMAIN"
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
}

# ===== Function to configure Nginx =====
configure_nginx() {
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
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
}

# ===== Function to reload Nginx =====
reload_nginx() {
    echo "🔄 Reloading Nginx..."
    sudo nginx -t && sudo systemctl restart nginx
}

# ===== Function to request SSL certificate =====
request_ssl() {
    echo "🔒 Requesting SSL certificate for $DOMAIN ..."
    if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN; then
        echo "✅ SSL issued for $DOMAIN"
    else
        echo "❌ Failed to issue SSL for $DOMAIN"
        exit 1
    fi
}

# ===== Function to enable SSL auto-renewal =====
enable_ssl_renewal() {
    echo "🔁 Enabling Certbot auto-renewal..."
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
}

# ===== Function to check domain reachability =====
check_domain_reachability() {
    echo "🌍 Checking if $DOMAIN is reachable..."
    if curl -s --head "https://$DOMAIN" | grep "200 OK" >/dev/null; then
        echo "✅ $DOMAIN is ready and live with HTTPS!"
    else
        echo "⚠️ $DOMAIN setup done, but it may take time for DNS to propagate."
    fi
}

# ===== Main execution =====
main() {
    # Step 1: Read domain name
    read_domain

    # Step 2: Install dependencies
    install_dependencies

    # Step 3: Setup web root
    setup_web_root

    # Step 4: Configure Nginx
    configure_nginx

    # Step 5: Reload Nginx
    reload_nginx

    # Step 6: Request SSL certificate
    request_ssl

    # Step 7: Enable SSL auto-renewal
    enable_ssl_renewal

    # Step 8: Check domain reachability
    check_domain_reachability

    echo "📌 Test in browser: https://$DOMAIN"
}

# Call the main function
main
