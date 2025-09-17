#!/bin/bash

# ============================================================
# SSL/Certbot Installation Script
# Description: Install and configure Certbot for Let's Encrypt SSL certificates
# Author: Anshul Yadav
# ============================================================

install_certbot() {
    echo "🔒 Starting Certbot installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install snapd if not already installed
    echo "📦 Installing snapd..."
    sudo apt install -y snapd
    
    # Install certbot via snap (recommended method)
    echo "⬇️ Installing Certbot via snap..."
    sudo snap install core; sudo snap refresh core
    sudo snap install --classic certbot
    
    # Create symlink for certbot command
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    
    # Install certbot plugins for different web servers
    echo "🔌 Installing Certbot plugins..."
    sudo snap install certbot-dns-cloudflare
    sudo snap install certbot-dns-route53
    
    # Check if installation was successful
    if command -v certbot &> /dev/null; then
        echo "✅ Certbot installed successfully!"
        
        # Get Certbot version
        CERTBOT_VERSION=$(certbot --version | cut -d' ' -f2)
        echo "📋 Certbot version: $CERTBOT_VERSION"
        
        # Setup automatic renewal
        setup_auto_renewal
        
        echo ""
        echo "🎉 Certbot installation completed successfully!"
        echo "📋 Certbot version: $CERTBOT_VERSION"
        echo "🔄 Auto-renewal: Enabled"
        
    else
        echo "❌ Certbot installation failed!"
        return 1
    fi
}

setup_auto_renewal() {
    echo "🔄 Setting up automatic certificate renewal..."
    
    # Test automatic renewal
    echo "🧪 Testing automatic renewal..."
    sudo certbot renew --dry-run
    
    if [ $? -eq 0 ]; then
        echo "✅ Automatic renewal test passed!"
        
        # Create renewal hook script
        create_renewal_hooks
        
        # Setup systemd timer for renewal (alternative to cron)
        setup_systemd_renewal
        
    else
        echo "⚠️ Automatic renewal test failed. Please check configuration."
    fi
}

create_renewal_hooks() {
    echo "🪝 Creating renewal hooks..."
    
    # Create hooks directory
    sudo mkdir -p /etc/letsencrypt/renewal-hooks/pre
    sudo mkdir -p /etc/letsencrypt/renewal-hooks/post
    sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    
    # Create pre-hook script (runs before renewal)
    sudo tee /etc/letsencrypt/renewal-hooks/pre/stop-services.sh > /dev/null << 'EOF'
#!/bin/bash
# Pre-renewal hook: Stop services if needed
echo "$(date): Pre-renewal hook executed" >> /var/log/letsencrypt/renewal.log

# Uncomment and modify as needed:
# systemctl stop nginx
# systemctl stop apache2
EOF
    
    # Create post-hook script (runs after renewal)
    sudo tee /etc/letsencrypt/renewal-hooks/post/restart-services.sh > /dev/null << 'EOF'
#!/bin/bash
# Post-renewal hook: Restart services
echo "$(date): Post-renewal hook executed" >> /var/log/letsencrypt/renewal.log

# Restart web servers
if systemctl is-active --quiet nginx; then
    systemctl reload nginx
    echo "$(date): Nginx reloaded" >> /var/log/letsencrypt/renewal.log
fi

if systemctl is-active --quiet apache2; then
    systemctl reload apache2
    echo "$(date): Apache2 reloaded" >> /var/log/letsencrypt/renewal.log
fi

# Send notification (optional)
# curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
#      -d "chat_id=<CHAT_ID>" \
#      -d "text=SSL certificate renewed successfully on $(hostname)"
EOF
    
    # Create deploy hook script (runs after successful renewal)
    sudo tee /etc/letsencrypt/renewal-hooks/deploy/deploy-cert.sh > /dev/null << 'EOF'
#!/bin/bash
# Deploy hook: Handle certificate deployment
echo "$(date): Deploy hook executed for $RENEWED_DOMAINS" >> /var/log/letsencrypt/renewal.log

# Copy certificates to custom locations if needed
# for domain in $RENEWED_DOMAINS; do
#     cp /etc/letsencrypt/live/$domain/fullchain.pem /path/to/custom/location/
#     cp /etc/letsencrypt/live/$domain/privkey.pem /path/to/custom/location/
# done

# Update file permissions
# chown -R www-data:www-data /etc/letsencrypt/live/
# chmod 600 /etc/letsencrypt/live/*/privkey.pem
EOF
    
    # Make hooks executable
    sudo chmod +x /etc/letsencrypt/renewal-hooks/pre/stop-services.sh
    sudo chmod +x /etc/letsencrypt/renewal-hooks/post/restart-services.sh
    sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/deploy-cert.sh
    
    # Create log directory
    sudo mkdir -p /var/log/letsencrypt
    sudo touch /var/log/letsencrypt/renewal.log
    
    echo "✅ Renewal hooks created successfully!"
}

setup_systemd_renewal() {
    echo "⏰ Setting up systemd timer for renewal..."
    
    # Create systemd service for renewal
    sudo tee /etc/systemd/system/certbot-renewal.service > /dev/null << 'EOF'
[Unit]
Description=Certbot Renewal
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --no-self-upgrade
PrivateTmp=true
EOF
    
    # Create systemd timer for renewal
    sudo tee /etc/systemd/system/certbot-renewal.timer > /dev/null << 'EOF'
[Unit]
Description=Run certbot twice daily
Requires=certbot-renewal.service

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start the timer
    sudo systemctl daemon-reload
    sudo systemctl enable certbot-renewal.timer
    sudo systemctl start certbot-renewal.timer
    
    echo "✅ Systemd timer configured successfully!"
    echo "📅 Renewal will run twice daily at 00:00 and 12:00"
}

install_web_server_integration() {
    echo "🌐 Setting up web server integration..."
    
    # Detect installed web servers
    NGINX_INSTALLED=false
    APACHE_INSTALLED=false
    
    if systemctl is-active --quiet nginx || command -v nginx &> /dev/null; then
        NGINX_INSTALLED=true
        echo "✅ Nginx detected"
    fi
    
    if systemctl is-active --quiet apache2 || command -v apache2 &> /dev/null; then
        APACHE_INSTALLED=true
        echo "✅ Apache2 detected"
    fi
    
    # Configure Nginx if installed
    if [ "$NGINX_INSTALLED" = true ]; then
        configure_nginx_ssl
    fi
    
    # Configure Apache if installed
    if [ "$APACHE_INSTALLED" = true ]; then
        configure_apache_ssl
    fi
    
    if [ "$NGINX_INSTALLED" = false ] && [ "$APACHE_INSTALLED" = false ]; then
        echo "⚠️ No web server detected. You'll need to configure SSL manually."
        echo "📖 Nginx installation: sudo apt install nginx"
        echo "📖 Apache installation: sudo apt install apache2"
    fi
}

configure_nginx_ssl() {
    echo "⚙️ Configuring Nginx for SSL..."
    
    # Create SSL configuration snippet
    sudo tee /etc/nginx/snippets/ssl-params.conf > /dev/null << 'EOF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF
    
    # Generate DH parameters if not exists
    if [ ! -f /etc/nginx/dhparam.pem ]; then
        echo "🔐 Generating DH parameters (this may take a while)..."
        sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
    fi
    
    # Create sample SSL site configuration
    sudo tee /etc/nginx/sites-available/ssl-example > /dev/null << 'EOF'
# Example SSL site configuration
# Copy and modify this for your domains

server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com www.example.com;
    
    root /var/www/html;
    index index.html index.htm index.php;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # PHP support (if needed)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
EOF
    
    echo "✅ Nginx SSL configuration created!"
    echo "📁 SSL params: /etc/nginx/snippets/ssl-params.conf"
    echo "📁 Example config: /etc/nginx/sites-available/ssl-example"
}

configure_apache_ssl() {
    echo "⚙️ Configuring Apache for SSL..."
    
    # Enable SSL module
    sudo a2enmod ssl
    sudo a2enmod rewrite
    sudo a2enmod headers
    
    # Create SSL configuration
    sudo tee /etc/apache2/conf-available/ssl-params.conf > /dev/null << 'EOF'
# SSL Configuration
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLHonorCipherOrder On
SSLCompression off
SSLUseStapling on
SSLStaplingCache "shmcb:logs/stapling-cache(150000)"

# Security headers
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
Header always set X-XSS-Protection "1; mode=block"
EOF
    
    # Enable SSL configuration
    sudo a2enconf ssl-params
    
    # Create sample SSL site configuration
    sudo tee /etc/apache2/sites-available/ssl-example.conf > /dev/null << 'EOF'
# Example SSL site configuration
# Copy and modify this for your domains

<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com
    Redirect permanent / https://example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com
    DocumentRoot /var/www/html
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem
    Include /etc/apache2/conf-available/ssl-params.conf
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/ssl_error.log
    CustomLog ${APACHE_LOG_DIR}/ssl_access.log combined
</VirtualHost>
EOF
    
    echo "✅ Apache SSL configuration created!"
    echo "📁 SSL params: /etc/apache2/conf-available/ssl-params.conf"
    echo "📁 Example config: /etc/apache2/sites-available/ssl-example.conf"
}

create_ssl_management_scripts() {
    echo "📜 Creating SSL management scripts..."
    
    # Create SSL management directory
    sudo mkdir -p /usr/local/bin/ssl-tools
    
    # Create certificate request script
    sudo tee /usr/local/bin/ssl-tools/request-cert.sh > /dev/null << 'EOF'
#!/bin/bash
# SSL Certificate Request Script

if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain> [additional_domains...]"
    echo "Example: $0 example.com www.example.com"
    exit 1
fi

DOMAIN=$1
shift
ADDITIONAL_DOMAINS=""

for domain in "$@"; do
    ADDITIONAL_DOMAINS="$ADDITIONAL_DOMAINS -d $domain"
done

echo "Requesting SSL certificate for: $DOMAIN $ADDITIONAL_DOMAINS"

# Request certificate
certbot certonly --nginx -d $DOMAIN $ADDITIONAL_DOMAINS

if [ $? -eq 0 ]; then
    echo "✅ Certificate obtained successfully!"
    echo "📁 Certificate location: /etc/letsencrypt/live/$DOMAIN/"
else
    echo "❌ Certificate request failed!"
    exit 1
fi
EOF
    
    # Create certificate status script
    sudo tee /usr/local/bin/ssl-tools/cert-status.sh > /dev/null << 'EOF'
#!/bin/bash
# SSL Certificate Status Script

echo "🔒 SSL Certificate Status"
echo "========================"

certbot certificates

echo ""
echo "📅 Next renewal check:"
certbot renew --dry-run
EOF
    
    # Create certificate revoke script
    sudo tee /usr/local/bin/ssl-tools/revoke-cert.sh > /dev/null << 'EOF'
#!/bin/bash
# SSL Certificate Revoke Script

if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN=$1

echo "Revoking SSL certificate for: $DOMAIN"
read -p "Are you sure? This action cannot be undone. (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    certbot revoke --cert-path /etc/letsencrypt/live/$DOMAIN/cert.pem
    certbot delete --cert-name $DOMAIN
    echo "✅ Certificate revoked and deleted!"
else
    echo "Operation cancelled."
fi
EOF
    
    # Make scripts executable
    sudo chmod +x /usr/local/bin/ssl-tools/*.sh
    
    # Create symlinks for easy access
    sudo ln -sf /usr/local/bin/ssl-tools/request-cert.sh /usr/local/bin/ssl-request
    sudo ln -sf /usr/local/bin/ssl-tools/cert-status.sh /usr/local/bin/ssl-status
    sudo ln -sf /usr/local/bin/ssl-tools/revoke-cert.sh /usr/local/bin/ssl-revoke
    
    echo "✅ SSL management scripts created!"
    echo "🚀 Commands available:"
    echo "   ssl-request <domain> [additional_domains...]"
    echo "   ssl-status"
    echo "   ssl-revoke <domain>"
}

# Function to check if Certbot is already installed
check_certbot_installed() {
    if command -v certbot &> /dev/null; then
        CERTBOT_VERSION=$(certbot --version | cut -d' ' -f2)
        echo "ℹ️ Certbot is already installed"
        echo "   Version: $CERTBOT_VERSION"
        read -p "Do you want to reinstall/upgrade? (y/N): " REINSTALL
        if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
            return 0
        else
            echo "Installation cancelled."
            return 1
        fi
    fi
    return 0
}

# Main execution
main() {
    echo "============================================================"
    echo "           SSL/Certbot Installation & Configuration"
    echo "============================================================"
    
    # Check if Certbot is already installed
    if ! check_certbot_installed; then
        exit 0
    fi
    
    # Ask about additional features
    read -p "Do you want to configure web server integration? (y/N): " CONFIGURE_WEBSERVER
    read -p "Do you want to create SSL management scripts? (y/N): " CREATE_SCRIPTS
    
    # Install Certbot
    install_certbot
    
    if [[ $? -eq 0 ]]; then
        # Configure web server if requested
        if [[ "$CONFIGURE_WEBSERVER" =~ ^[Yy]$ ]]; then
            install_web_server_integration
        fi
        
        # Create management scripts if requested
        if [[ "$CREATE_SCRIPTS" =~ ^[Yy]$ ]]; then
            create_ssl_management_scripts
        fi
        
        echo ""
        echo "✅ All done! Certbot is ready to use."
        echo "🚀 Request certificate: certbot --nginx -d yourdomain.com"
        echo "📊 Check certificates: certbot certificates"
        echo "🔄 Test renewal: certbot renew --dry-run"
        echo "⏰ Auto-renewal: systemctl status certbot-renewal.timer"
        
        if [[ "$CREATE_SCRIPTS" =~ ^[Yy]$ ]]; then
            echo "🛠️ Management tools: ssl-request, ssl-status, ssl-revoke"
        fi
        
        echo ""
        echo "📖 Next steps:"
        echo "   1. Ensure your domain points to this server"
        echo "   2. Configure your web server"
        echo "   3. Request your first certificate"
        
    else
        echo "❌ Installation failed. Please check the errors above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi