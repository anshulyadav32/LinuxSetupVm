#!/bin/bash

# ============================================================
# Apache Web Server Installation Script
# Description: Install and configure Apache with SSL and security
# Author: Anshul Yadav
# ============================================================

check_apache_installed() {
    if systemctl is-active --quiet apache2; then
        echo "⚠️ Apache is already installed and running!"
        apache2 -v
        read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
        if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

install_apache() {
    echo "🌐 Installing Apache Web Server..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install Apache and modules
    echo "⬇️ Installing Apache and essential modules..."
    sudo apt install -y \
        apache2 \
        apache2-utils \
        libapache2-mod-security2 \
        libapache2-mod-evasive \
        libapache2-mod-php \
        ssl-cert
    
    # Enable essential modules
    echo "🔧 Enabling Apache modules..."
    sudo a2enmod rewrite
    sudo a2enmod ssl
    sudo a2enmod headers
    sudo a2enmod security2
    sudo a2enmod evasive24
    sudo a2enmod deflate
    sudo a2enmod expires
    sudo a2enmod include
    sudo a2enmod proxy
    sudo a2enmod proxy_http
    sudo a2enmod proxy_balancer
    sudo a2enmod lbmethod_byrequests
    
    # Start and enable Apache
    sudo systemctl start apache2
    sudo systemctl enable apache2
    
    echo "✅ Apache installed and started!"
}

configure_security() {
    echo "🔒 Configuring Apache security..."
    
    # Create security configuration
    sudo tee /etc/apache2/conf-available/security-custom.conf > /dev/null << 'EOF'
# Hide Apache version and OS information
ServerTokens Prod
ServerSignature Off

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"

# Disable server-status and server-info
<Location "/server-status">
    Require local
</Location>

<Location "/server-info">
    Require local
</Location>

# Disable trace method
TraceEnable Off

# Timeout settings
Timeout 60
KeepAliveTimeout 5

# Limit request size (10MB)
LimitRequestBody 10485760
EOF
    
    # Enable security configuration
    sudo a2enconf security-custom
    
    # Configure ModSecurity
    echo "🛡️ Configuring ModSecurity..."
    sudo cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
    sudo sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
    
    # Configure ModEvasive
    echo "🚫 Configuring ModEvasive (DDoS protection)..."
    sudo tee /etc/apache2/mods-available/evasive.conf > /dev/null << 'EOF'
<IfModule mod_evasive24.c>
    DOSHashTableSize    2048
    DOSPageCount        3
    DOSPageInterval     1
    DOSSiteCount        50
    DOSSiteInterval     1
    DOSBlockingPeriod   600
    DOSLogDir           "/var/log/apache2"
    DOSEmailNotify      admin@localhost
</IfModule>
EOF
    
    echo "✅ Security configured!"
}

configure_performance() {
    echo "⚡ Configuring Apache performance..."
    
    # Create performance configuration
    sudo tee /etc/apache2/conf-available/performance.conf > /dev/null << 'EOF'
# Compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
    AddOutputFilterByType DEFLATE application/json
</IfModule>

# Caching
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/pdf "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType application/x-javascript "access plus 1 month"
    ExpiresByType application/x-shockwave-flash "access plus 1 month"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresDefault "access plus 2 days"
</IfModule>

# ETags
FileETag None
EOF
    
    # Enable performance configuration
    sudo a2enconf performance
    
    echo "✅ Performance optimized!"
}

create_virtual_hosts() {
    echo "🏠 Creating virtual host templates..."
    
    # Create sites directory
    sudo mkdir -p /var/www/html/default
    sudo mkdir -p /var/www/html/ssl-default
    
    # Default HTTP virtual host
    sudo tee /etc/apache2/sites-available/000-default-custom.conf > /dev/null << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/default
    
    ErrorLog ${APACHE_LOG_DIR}/default_error.log
    CustomLog ${APACHE_LOG_DIR}/default_access.log combined
    
    # Security
    <Directory /var/www/html/default>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Hide sensitive files
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>
    
    <FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
        Require all denied
    </FilesMatch>
</VirtualHost>
EOF
    
    # Default HTTPS virtual host
    sudo tee /etc/apache2/sites-available/default-ssl-custom.conf > /dev/null << 'EOF'
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/ssl-default
        
        ErrorLog ${APACHE_LOG_DIR}/ssl_error.log
        CustomLog ${APACHE_LOG_DIR}/ssl_access.log combined
        
        # SSL Configuration
        SSLEngine on
        SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
        
        # Modern SSL configuration
        SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
        SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
        SSLHonorCipherOrder off
        SSLSessionTickets off
        
        # Security headers for HTTPS
        Header always set Strict-Transport-Security "max-age=63072000"
        
        <Directory /var/www/html/ssl-default>
            Options -Indexes +FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
        
        # Hide sensitive files
        <FilesMatch "^\.">
            Require all denied
        </FilesMatch>
        
        <FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
            Require all denied
        </FilesMatch>
    </VirtualHost>
</IfModule>
EOF
    
    # Create sample index files
    sudo tee /var/www/html/default/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Apache Default Page</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Apache Web Server</h1>
        <p class="status">✅ Apache is running successfully!</p>
        <p>This is the default Apache virtual host page.</p>
        <hr>
        <small>Server: <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Apache'; ?></small>
    </div>
</body>
</html>
EOF
    
    sudo cp /var/www/html/default/index.html /var/www/html/ssl-default/index.html
    
    # Set permissions
    sudo chown -R www-data:www-data /var/www/html/
    sudo chmod -R 755 /var/www/html/
    
    echo "✅ Virtual hosts created!"
}

create_management_scripts() {
    echo "📜 Creating Apache management scripts..."
    
    mkdir -p ~/bin
    
    # Apache status script
    cat > ~/bin/apache-status << 'EOF'
#!/bin/bash
echo "🌐 Apache Status"
echo "==============="
systemctl status apache2 --no-pager
echo ""
echo "📊 Active Sites:"
apache2ctl -S
echo ""
echo "🔗 Loaded Modules:"
apache2ctl -M | head -20
EOF
    
    # Virtual host creator script
    cat > ~/bin/create-vhost << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: create-vhost <domain>"
    echo "Example: create-vhost example.com"
    exit 1
fi

DOMAIN=$1
VHOST_DIR="/var/www/html/$DOMAIN"
CONF_FILE="/etc/apache2/sites-available/$DOMAIN.conf"

echo "🏠 Creating virtual host for: $DOMAIN"

# Create directory
sudo mkdir -p "$VHOST_DIR"

# Create virtual host config
sudo tee "$CONF_FILE" > /dev/null << EOL
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $VHOST_DIR
    
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
    
    <Directory $VHOST_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

# Create sample index
sudo tee "$VHOST_DIR/index.html" > /dev/null << EOL
<!DOCTYPE html>
<html>
<head><title>$DOMAIN</title></head>
<body>
    <h1>Welcome to $DOMAIN</h1>
    <p>This site is working!</p>
</body>
</html>
EOL

# Set permissions
sudo chown -R www-data:www-data "$VHOST_DIR"
sudo chmod -R 755 "$VHOST_DIR"

# Enable site
sudo a2ensite "$DOMAIN"
sudo systemctl reload apache2

echo "✅ Virtual host created for $DOMAIN"
echo "📁 Document root: $VHOST_DIR"
echo "⚙️ Config file: $CONF_FILE"
EOF
    
    # SSL certificate script
    cat > ~/bin/apache-ssl << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: apache-ssl <domain>"
    echo "This script helps set up SSL for Apache virtual hosts"
    exit 1
fi

DOMAIN=$1
echo "🔒 SSL Setup for: $DOMAIN"
echo "This script assumes you have Certbot installed."
echo "Run: sudo certbot --apache -d $DOMAIN -d www.$DOMAIN"
EOF
    
    chmod +x ~/bin/apache-*
    chmod +x ~/bin/create-vhost
    
    echo "✅ Management scripts created!"
}

# Main execution
main() {
    echo "============================================================"
    echo "              Apache Web Server Installation"
    echo "============================================================"
    
    check_apache_installed
    
    read -p "Install Apache? (Y/n): " INSTALL_APACHE
    read -p "Configure security settings? (Y/n): " CONFIGURE_SECURITY
    read -p "Configure performance optimization? (Y/n): " CONFIGURE_PERFORMANCE
    read -p "Create virtual host templates? (Y/n): " CREATE_VHOSTS
    read -p "Create management scripts? (Y/n): " CREATE_SCRIPTS
    
    if [[ ! "$INSTALL_APACHE" =~ ^[Nn]$ ]]; then
        install_apache
    fi
    
    if [[ ! "$CONFIGURE_SECURITY" =~ ^[Nn]$ ]]; then
        configure_security
    fi
    
    if [[ ! "$CONFIGURE_PERFORMANCE" =~ ^[Nn]$ ]]; then
        configure_performance
    fi
    
    if [[ ! "$CREATE_VHOSTS" =~ ^[Nn]$ ]]; then
        create_virtual_hosts
    fi
    
    if [[ ! "$CREATE_SCRIPTS" =~ ^[Nn]$ ]]; then
        create_management_scripts
    fi
    
    # Restart Apache to apply all configurations
    echo "🔄 Restarting Apache to apply configurations..."
    sudo systemctl restart apache2
    
    echo ""
    echo "✅ Apache installation and configuration completed!"
    echo ""
    echo "🌐 Apache Status:"
    systemctl status apache2 --no-pager -l
    echo ""
    echo "🚀 Quick Commands:"
    echo "  sudo systemctl start apache2    # Start Apache"
    echo "  sudo systemctl stop apache2     # Stop Apache"
    echo "  sudo systemctl restart apache2  # Restart Apache"
    echo "  sudo systemctl reload apache2   # Reload config"
    echo "  apache2ctl configtest           # Test config"
    echo ""
    echo "📜 Management Scripts:"
    echo "  apache-status                   # Show Apache status"
    echo "  create-vhost <domain>           # Create virtual host"
    echo "  apache-ssl <domain>             # SSL setup helper"
    echo ""
    echo "📁 Important Directories:"
    echo "  /var/www/html/                  # Web root"
    echo "  /etc/apache2/sites-available/   # Virtual host configs"
    echo "  /var/log/apache2/               # Log files"
    echo ""
    echo "🔗 Test your installation:"
    echo "  http://localhost"
    echo "  https://localhost (with self-signed cert)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi