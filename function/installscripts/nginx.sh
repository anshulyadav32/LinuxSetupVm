#!/bin/bash

# ============================================================
# Nginx Installation Script
# Description: Install latest version of Nginx web server
# Author: Anshul Yadav
# ============================================================

install_nginx() {
    echo "🚀 Starting Nginx installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install Nginx
    echo "⬇️ Installing Nginx latest version..."
    sudo apt install -y nginx
    
    # Check if installation was successful
    if command -v nginx &> /dev/null; then
        echo "✅ Nginx installed successfully!"
        
        # Get installed version
        NGINX_VERSION=$(nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        echo "📋 Installed version: $NGINX_VERSION"
        
        # Start and enable Nginx service
        echo "🔄 Starting Nginx service..."
        sudo systemctl start nginx
        sudo systemctl enable nginx
        
        # Check service status
        if sudo systemctl is-active --quiet nginx; then
            echo "✅ Nginx service is running!"
        else
            echo "❌ Failed to start Nginx service"
            return 1
        fi
        
        # Configure firewall
        echo "🔥 Configuring firewall..."
        sudo ufw allow 'Nginx Full'
        
        # Display status
        echo "📊 Nginx Status:"
        sudo systemctl status nginx --no-pager -l
        
        echo ""
        echo "🎉 Nginx installation completed successfully!"
        echo "🌐 You can access your web server at: http://$(hostname -I | awk '{print $1}')"
        echo "📁 Default web root: /var/www/html"
        echo "⚙️ Configuration file: /etc/nginx/nginx.conf"
        echo "📝 Site configuration: /etc/nginx/sites-available/default"
        
    else
        echo "❌ Nginx installation failed!"
        return 1
    fi
}

# Function to check if Nginx is already installed
check_nginx_installed() {
    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        echo "ℹ️ Nginx is already installed (version: $NGINX_VERSION)"
        read -p "Do you want to reinstall? (y/N): " REINSTALL
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
    echo "           Nginx Latest Version Installer"
    echo "============================================================"
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        echo "⚠️ Running as root. This is not recommended."
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi
    
    # Check if Nginx is already installed
    if ! check_nginx_installed; then
        exit 0
    fi
    
    # Install Nginx
    install_nginx
    
    if [[ $? -eq 0 ]]; then
        echo "✅ All done! Nginx is ready to serve your content."
    else
        echo "❌ Installation failed. Please check the errors above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi