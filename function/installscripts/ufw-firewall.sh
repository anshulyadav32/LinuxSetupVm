#!/bin/bash

# ============================================================
# UFW Firewall Setup Script
# Description: Install and configure UFW firewall with common security rules
# Author: Anshul Yadav
# ============================================================

install_ufw() {
    echo "🔥 Starting UFW firewall installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install UFW
    echo "⬇️ Installing UFW..."
    sudo apt install -y ufw
    
    # Check if installation was successful
    if command -v ufw &> /dev/null; then
        echo "✅ UFW installed successfully!"
        
        # Get UFW version
        UFW_VERSION=$(ufw --version | head -1 | cut -d' ' -f2)
        echo "📋 UFW version: $UFW_VERSION"
        
        # Configure UFW
        configure_ufw_basic
        
        echo ""
        echo "🎉 UFW installation completed successfully!"
        echo "📋 UFW version: $UFW_VERSION"
        
    else
        echo "❌ UFW installation failed!"
        return 1
    fi
}

configure_ufw_basic() {
    echo "⚙️ Configuring UFW with basic security rules..."
    
    # Reset UFW to defaults (clean slate)
    echo "🔄 Resetting UFW to defaults..."
    sudo ufw --force reset
    
    # Set default policies
    echo "🛡️ Setting default policies..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw default deny forward
    
    # Allow SSH (important - don't lock yourself out!)
    echo "🔑 Allowing SSH access..."
    sudo ufw allow ssh
    sudo ufw allow 22/tcp
    
    # Basic logging
    sudo ufw logging on
    
    echo "✅ Basic UFW configuration completed!"
}

setup_web_server_rules() {
    echo "🌐 Setting up web server firewall rules..."
    
    # HTTP and HTTPS
    echo "📡 Allowing HTTP and HTTPS traffic..."
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    
    # Alternative HTTP ports
    read -p "Allow alternative HTTP ports (8080, 8443)? (y/N): " ALT_HTTP
    if [[ "$ALT_HTTP" =~ ^[Yy]$ ]]; then
        sudo ufw allow 8080/tcp comment 'HTTP Alternative'
        sudo ufw allow 8443/tcp comment 'HTTPS Alternative'
    fi
    
    echo "✅ Web server rules configured!"
}

setup_database_rules() {
    echo "🗄️ Setting up database firewall rules..."
    
    # MySQL/MariaDB
    read -p "Allow MySQL/MariaDB (port 3306)? (y/N): " MYSQL
    if [[ "$MYSQL" =~ ^[Yy]$ ]]; then
        read -p "Allow from specific IP/subnet only? (y/N): " MYSQL_SPECIFIC
        if [[ "$MYSQL_SPECIFIC" =~ ^[Yy]$ ]]; then
            read -p "Enter IP/subnet (e.g., 192.168.1.0/24): " MYSQL_IP
            sudo ufw allow from $MYSQL_IP to any port 3306 comment 'MySQL from specific network'
        else
            sudo ufw allow 3306/tcp comment 'MySQL'
        fi
    fi
    
    # PostgreSQL
    read -p "Allow PostgreSQL (port 5432)? (y/N): " POSTGRES
    if [[ "$POSTGRES" =~ ^[Yy]$ ]]; then
        read -p "Allow from specific IP/subnet only? (y/N): " POSTGRES_SPECIFIC
        if [[ "$POSTGRES_SPECIFIC" =~ ^[Yy]$ ]]; then
            read -p "Enter IP/subnet (e.g., 192.168.1.0/24): " POSTGRES_IP
            sudo ufw allow from $POSTGRES_IP to any port 5432 comment 'PostgreSQL from specific network'
        else
            sudo ufw allow 5432/tcp comment 'PostgreSQL'
        fi
    fi
    
    # Redis
    read -p "Allow Redis (port 6379)? (y/N): " REDIS
    if [[ "$REDIS" =~ ^[Yy]$ ]]; then
        read -p "Allow from specific IP/subnet only? (y/N): " REDIS_SPECIFIC
        if [[ "$REDIS_SPECIFIC" =~ ^[Yy]$ ]]; then
            read -p "Enter IP/subnet (e.g., 192.168.1.0/24): " REDIS_IP
            sudo ufw allow from $REDIS_IP to any port 6379 comment 'Redis from specific network'
        else
            sudo ufw allow 6379/tcp comment 'Redis'
        fi
    fi
    
    # MongoDB
    read -p "Allow MongoDB (port 27017)? (y/N): " MONGODB
    if [[ "$MONGODB" =~ ^[Yy]$ ]]; then
        read -p "Allow from specific IP/subnet only? (y/N): " MONGODB_SPECIFIC
        if [[ "$MONGODB_SPECIFIC" =~ ^[Yy]$ ]]; then
            read -p "Enter IP/subnet (e.g., 192.168.1.0/24): " MONGODB_IP
            sudo ufw allow from $MONGODB_IP to any port 27017 comment 'MongoDB from specific network'
        else
            sudo ufw allow 27017/tcp comment 'MongoDB'
        fi
    fi
    
    echo "✅ Database rules configured!"
}

setup_development_rules() {
    echo "💻 Setting up development firewall rules..."
    
    # Common development ports
    DEV_PORTS=(
        "3000:React/Node.js dev server"
        "3001:Alternative dev server"
        "4000:GraphQL/Apollo"
        "5000:Flask/Express"
        "5173:Vite dev server"
        "8000:Django/Python dev"
        "8080:Alternative HTTP"
        "9000:PHP-FPM/Xdebug"
        "9001:Supervisor"
        "9200:Elasticsearch"
        "9300:Elasticsearch cluster"
    )
    
    echo "Common development ports:"
    for i in "${!DEV_PORTS[@]}"; do
        echo "$((i+1)). ${DEV_PORTS[i]}"
    done
    
    read -p "Select ports to allow (comma-separated numbers, or 'all' for all): " DEV_SELECTION
    
    if [[ "$DEV_SELECTION" == "all" ]]; then
        for port_desc in "${DEV_PORTS[@]}"; do
            port=$(echo $port_desc | cut -d':' -f1)
            desc=$(echo $port_desc | cut -d':' -f2)
            sudo ufw allow $port/tcp comment "Dev: $desc"
        done
    else
        IFS=',' read -ra SELECTED <<< "$DEV_SELECTION"
        for i in "${SELECTED[@]}"; do
            if [[ $i -ge 1 && $i -le ${#DEV_PORTS[@]} ]]; then
                port_desc="${DEV_PORTS[$((i-1))]}"
                port=$(echo $port_desc | cut -d':' -f1)
                desc=$(echo $port_desc | cut -d':' -f2)
                sudo ufw allow $port/tcp comment "Dev: $desc"
            fi
        done
    fi
    
    echo "✅ Development rules configured!"
}

setup_security_rules() {
    echo "🔒 Setting up advanced security rules..."
    
    # Rate limiting for SSH
    echo "⚡ Setting up SSH rate limiting..."
    sudo ufw limit ssh comment 'SSH rate limiting'
    
    # Block common attack ports
    echo "🚫 Blocking common attack ports..."
    BLOCK_PORTS=(135 139 445 1433 1434 3389 5900)
    for port in "${BLOCK_PORTS[@]}"; do
        sudo ufw deny $port comment "Block common attack port $port"
    done
    
    # Allow ping (ICMP)
    read -p "Allow ping (ICMP)? (y/N): " ALLOW_PING
    if [[ "$ALLOW_PING" =~ ^[Yy]$ ]]; then
        sudo ufw allow in on any to any port 22 proto icmp comment 'Allow ping'
    else
        sudo ufw deny in on any to any port 22 proto icmp comment 'Block ping'
    fi
    
    # Geo-blocking (if geoip is available)
    setup_geo_blocking
    
    echo "✅ Security rules configured!"
}

setup_geo_blocking() {
    echo "🌍 Setting up geo-blocking (optional)..."
    
    # Check if geoip modules are available
    if dpkg -l | grep -q geoip; then
        read -p "Block traffic from specific countries? (y/N): " GEO_BLOCK
        if [[ "$GEO_BLOCK" =~ ^[Yy]$ ]]; then
            echo "Note: This requires xtables-addons and geoip database"
            echo "Install with: sudo apt install xtables-addons-common"
            read -p "Enter country codes to block (e.g., CN,RU,KP): " COUNTRIES
            echo "# Add to /etc/ufw/before.rules for geo-blocking:"
            echo "# -A ufw-before-input -m geoip --src-cc $COUNTRIES -j DROP"
        fi
    else
        echo "ℹ️ GeoIP modules not installed. Skipping geo-blocking."
    fi
}

setup_application_profiles() {
    echo "📱 Setting up application profiles..."
    
    # Create custom application profiles
    sudo mkdir -p /etc/ufw/applications.d
    
    # Docker profile
    sudo tee /etc/ufw/applications.d/docker > /dev/null << 'EOF'
[Docker]
title=Docker
description=Docker container platform
ports=2375,2376/tcp

[Docker Swarm]
title=Docker Swarm
description=Docker Swarm cluster communication
ports=2377,7946/tcp|7946/udp|4789/udp
EOF
    
    # Node.js profile
    sudo tee /etc/ufw/applications.d/nodejs > /dev/null << 'EOF'
[Node.js]
title=Node.js
description=Node.js application server
ports=3000/tcp

[Node.js Dev]
title=Node.js Development
description=Node.js development servers
ports=3000,3001,5000,8000/tcp
EOF
    
    # Nginx profile (if not exists)
    if [ ! -f /etc/ufw/applications.d/nginx ]; then
        sudo tee /etc/ufw/applications.d/nginx > /dev/null << 'EOF'
[Nginx HTTP]
title=Web Server (Nginx, HTTP)
description=Small, but very powerful and efficient web server
ports=80/tcp

[Nginx HTTPS]
title=Web Server (Nginx, HTTPS)
description=Small, but very powerful and efficient web server
ports=443/tcp

[Nginx Full]
title=Web Server (Nginx, HTTP + HTTPS)
description=Small, but very powerful and efficient web server
ports=80,443/tcp
EOF
    fi
    
    # Reload application profiles
    sudo ufw app update all
    
    echo "✅ Application profiles created!"
    echo "📋 Available profiles: $(sudo ufw app list | grep -v '^Available' | tr '\n' ' ')"
}

create_firewall_management_scripts() {
    echo "📜 Creating firewall management scripts..."
    
    # Create firewall tools directory
    sudo mkdir -p /usr/local/bin/firewall-tools
    
    # Create status script
    sudo tee /usr/local/bin/firewall-tools/fw-status.sh > /dev/null << 'EOF'
#!/bin/bash
# Firewall Status Script

echo "🔥 UFW Firewall Status"
echo "====================="

# UFW status
sudo ufw status verbose

echo ""
echo "📊 UFW Statistics:"
echo "=================="

# Show numbered rules
sudo ufw status numbered

echo ""
echo "📋 Application Profiles:"
echo "========================"
sudo ufw app list

echo ""
echo "📈 Recent Log Entries:"
echo "======================"
sudo tail -10 /var/log/ufw.log 2>/dev/null || echo "No UFW logs found"
EOF
    
    # Create backup script
    sudo tee /usr/local/bin/firewall-tools/fw-backup.sh > /dev/null << 'EOF'
#!/bin/bash
# Firewall Backup Script

BACKUP_DIR="/etc/ufw/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/ufw_backup_$TIMESTAMP.tar.gz"

echo "💾 Creating UFW backup..."

# Create backup directory
sudo mkdir -p $BACKUP_DIR

# Create backup
sudo tar -czf $BACKUP_FILE /etc/ufw/ /lib/ufw/ 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Backup created: $BACKUP_FILE"
    
    # Keep only last 5 backups
    sudo find $BACKUP_DIR -name "ufw_backup_*.tar.gz" -type f | sort -r | tail -n +6 | sudo xargs rm -f
    
    echo "📁 Available backups:"
    sudo ls -la $BACKUP_DIR/ufw_backup_*.tar.gz 2>/dev/null || echo "No backups found"
else
    echo "❌ Backup failed!"
    exit 1
fi
EOF
    
    # Create restore script
    sudo tee /usr/local/bin/firewall-tools/fw-restore.sh > /dev/null << 'EOF'
#!/bin/bash
# Firewall Restore Script

BACKUP_DIR="/etc/ufw/backups"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Available backups:"
    sudo ls -la $BACKUP_DIR/ufw_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restoring UFW from backup: $BACKUP_FILE"
read -p "This will overwrite current UFW configuration. Continue? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    # Disable UFW first
    sudo ufw --force disable
    
    # Restore backup
    sudo tar -xzf $BACKUP_FILE -C / 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Backup restored successfully!"
        echo "🔄 Reloading UFW..."
        sudo ufw --force enable
        sudo ufw reload
    else
        echo "❌ Restore failed!"
        exit 1
    fi
else
    echo "Operation cancelled."
fi
EOF
    
    # Create quick rules script
    sudo tee /usr/local/bin/firewall-tools/fw-quick.sh > /dev/null << 'EOF'
#!/bin/bash
# Quick Firewall Rules Script

case $1 in
    "web")
        echo "🌐 Allowing web traffic..."
        sudo ufw allow 80/tcp comment 'HTTP'
        sudo ufw allow 443/tcp comment 'HTTPS'
        ;;
    "ssh")
        echo "🔑 Allowing SSH..."
        sudo ufw allow ssh
        ;;
    "dev")
        echo "💻 Allowing common dev ports..."
        sudo ufw allow 3000/tcp comment 'Dev server'
        sudo ufw allow 8000/tcp comment 'Dev server alt'
        ;;
    "block-ip")
        if [ -z "$2" ]; then
            echo "Usage: $0 block-ip <IP_ADDRESS>"
            exit 1
        fi
        echo "🚫 Blocking IP: $2"
        sudo ufw deny from $2
        ;;
    "allow-ip")
        if [ -z "$2" ]; then
            echo "Usage: $0 allow-ip <IP_ADDRESS>"
            exit 1
        fi
        echo "✅ Allowing IP: $2"
        sudo ufw allow from $2
        ;;
    *)
        echo "Usage: $0 {web|ssh|dev|block-ip <ip>|allow-ip <ip>}"
        echo ""
        echo "Quick firewall rules:"
        echo "  web      - Allow HTTP and HTTPS"
        echo "  ssh      - Allow SSH"
        echo "  dev      - Allow common development ports"
        echo "  block-ip - Block specific IP address"
        echo "  allow-ip - Allow specific IP address"
        ;;
esac
EOF
    
    # Make scripts executable
    sudo chmod +x /usr/local/bin/firewall-tools/*.sh
    
    # Create symlinks for easy access
    sudo ln -sf /usr/local/bin/firewall-tools/fw-status.sh /usr/local/bin/fw-status
    sudo ln -sf /usr/local/bin/firewall-tools/fw-backup.sh /usr/local/bin/fw-backup
    sudo ln -sf /usr/local/bin/firewall-tools/fw-restore.sh /usr/local/bin/fw-restore
    sudo ln -sf /usr/local/bin/firewall-tools/fw-quick.sh /usr/local/bin/fw-quick
    
    echo "✅ Firewall management scripts created!"
    echo "🚀 Commands available:"
    echo "   fw-status  - Show firewall status"
    echo "   fw-backup  - Create firewall backup"
    echo "   fw-restore - Restore firewall backup"
    echo "   fw-quick   - Quick firewall rules"
}

enable_ufw() {
    echo "🚀 Enabling UFW firewall..."
    
    # Show current rules before enabling
    echo "📋 Current UFW rules:"
    sudo ufw status numbered
    
    echo ""
    read -p "Enable UFW firewall with these rules? (y/N): " ENABLE_UFW
    
    if [[ "$ENABLE_UFW" =~ ^[Yy]$ ]]; then
        sudo ufw --force enable
        
        if [ $? -eq 0 ]; then
            echo "✅ UFW firewall enabled successfully!"
            
            # Show final status
            echo ""
            echo "🔥 Final UFW Status:"
            sudo ufw status verbose
            
        else
            echo "❌ Failed to enable UFW firewall!"
            return 1
        fi
    else
        echo "⚠️ UFW firewall not enabled. You can enable it later with: sudo ufw enable"
    fi
}

# Function to check if UFW is already installed
check_ufw_installed() {
    if command -v ufw &> /dev/null; then
        UFW_STATUS=$(sudo ufw status | head -1)
        echo "ℹ️ UFW is already installed"
        echo "   Status: $UFW_STATUS"
        read -p "Do you want to reconfigure UFW? (y/N): " RECONFIGURE
        if [[ "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            return 0
        else
            echo "Configuration cancelled."
            return 1
        fi
    fi
    return 0
}

# Main execution
main() {
    echo "============================================================"
    echo "           UFW Firewall Installation & Configuration"
    echo "============================================================"
    
    # Check if UFW is already installed
    if ! check_ufw_installed; then
        exit 0
    fi
    
    # Ask about configuration options
    echo ""
    echo "🔧 Configuration Options:"
    read -p "Configure web server rules (HTTP/HTTPS)? (y/N): " SETUP_WEB
    read -p "Configure database rules? (y/N): " SETUP_DB
    read -p "Configure development rules? (y/N): " SETUP_DEV
    read -p "Configure advanced security rules? (y/N): " SETUP_SECURITY
    read -p "Create application profiles? (y/N): " SETUP_PROFILES
    read -p "Create management scripts? (y/N): " CREATE_SCRIPTS
    
    # Install UFW
    install_ufw
    
    if [[ $? -eq 0 ]]; then
        # Configure based on user choices
        if [[ "$SETUP_WEB" =~ ^[Yy]$ ]]; then
            setup_web_server_rules
        fi
        
        if [[ "$SETUP_DB" =~ ^[Yy]$ ]]; then
            setup_database_rules
        fi
        
        if [[ "$SETUP_DEV" =~ ^[Yy]$ ]]; then
            setup_development_rules
        fi
        
        if [[ "$SETUP_SECURITY" =~ ^[Yy]$ ]]; then
            setup_security_rules
        fi
        
        if [[ "$SETUP_PROFILES" =~ ^[Yy]$ ]]; then
            setup_application_profiles
        fi
        
        if [[ "$CREATE_SCRIPTS" =~ ^[Yy]$ ]]; then
            create_firewall_management_scripts
        fi
        
        # Enable UFW
        enable_ufw
        
        echo ""
        echo "✅ All done! UFW firewall is configured."
        echo "🚀 Check status: sudo ufw status"
        echo "📊 Detailed status: sudo ufw status verbose"
        echo "📋 List rules: sudo ufw status numbered"
        echo "🔧 Manage rules: sudo ufw allow/deny <port>"
        
        if [[ "$CREATE_SCRIPTS" =~ ^[Yy]$ ]]; then
            echo "🛠️ Management tools: fw-status, fw-backup, fw-restore, fw-quick"
        fi
        
        echo ""
        echo "⚠️ Important reminders:"
        echo "   - SSH access is allowed to prevent lockout"
        echo "   - Test your configuration before disconnecting"
        echo "   - Keep backups of your firewall rules"
        echo "   - Monitor logs: sudo tail -f /var/log/ufw.log"
        
    else
        echo "❌ Installation failed. Please check the errors above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi