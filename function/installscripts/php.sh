#!/bin/bash

# ============================================================
# PHP Installation Script
# Description: Install PHP with common extensions and configuration
# Author: Anshul Yadav
# ============================================================

install_php() {
    echo "🐘 Starting PHP installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Add PHP repository for latest versions
    echo "📂 Adding PHP repository..."
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    
    # Get latest PHP version available
    PHP_VERSION=$(apt-cache search php8 | grep -E "php8\.[0-9]+" | sort -V | tail -1 | cut -d' ' -f1 | grep -o '[0-9]\+\.[0-9]\+')
    if [ -z "$PHP_VERSION" ]; then
        PHP_VERSION="8.2"  # Fallback version
    fi
    
    echo "📋 Installing PHP $PHP_VERSION..."
    
    # Install PHP and common extensions
    echo "⬇️ Installing PHP and extensions..."
    sudo apt install -y \
        php${PHP_VERSION} \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-mongodb \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-imagick \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-xmlrpc \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-json \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-xdebug \
        php${PHP_VERSION}-dev \
        libapache2-mod-php${PHP_VERSION}
    
    # Start and enable PHP-FPM
    echo "🚀 Starting PHP-FPM service..."
    sudo systemctl start php${PHP_VERSION}-fpm
    sudo systemctl enable php${PHP_VERSION}-fpm
    
    # Check if installation was successful
    if command -v php &> /dev/null; then
        echo "✅ PHP installed successfully!"
        
        # Get PHP version
        INSTALLED_PHP_VERSION=$(php --version | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        echo "📋 PHP version: $INSTALLED_PHP_VERSION"
        
        # Configure PHP
        configure_php
        
        # Install Composer
        install_composer
        
        echo ""
        echo "🎉 PHP installation completed successfully!"
        echo "📋 PHP version: $INSTALLED_PHP_VERSION"
        echo "🔧 PHP-FPM status: $(systemctl is-active php${PHP_VERSION}-fpm)"
        echo "📁 PHP config: /etc/php/${PHP_VERSION}/"
        
    else
        echo "❌ PHP installation failed!"
        return 1
    fi
}

configure_php() {
    echo "⚙️ Configuring PHP..."
    
    # Get PHP version for config paths
    PHP_VER=$(php --version | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    
    # Backup original configurations
    sudo cp /etc/php/${PHP_VER}/cli/php.ini /etc/php/${PHP_VER}/cli/php.ini.backup
    sudo cp /etc/php/${PHP_VER}/fpm/php.ini /etc/php/${PHP_VER}/fpm/php.ini.backup
    
    # Configure PHP CLI
    echo "⚙️ Configuring PHP CLI..."
    sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/${PHP_VER}/cli/php.ini
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/${PHP_VER}/cli/php.ini
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/${PHP_VER}/cli/php.ini
    sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/${PHP_VER}/cli/php.ini
    sudo sed -i 's/;date.timezone =.*/date.timezone = UTC/' /etc/php/${PHP_VER}/cli/php.ini
    
    # Configure PHP-FPM
    echo "⚙️ Configuring PHP-FPM..."
    sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/${PHP_VER}/fpm/php.ini
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 60/' /etc/php/${PHP_VER}/fpm/php.ini
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' /etc/php/${PHP_VER}/fpm/php.ini
    sudo sed -i 's/post_max_size = .*/post_max_size = 50M/' /etc/php/${PHP_VER}/fpm/php.ini
    sudo sed -i 's/;date.timezone =.*/date.timezone = UTC/' /etc/php/${PHP_VER}/fpm/php.ini
    
    # Configure OPcache
    echo "⚡ Configuring OPcache..."
    sudo tee /etc/php/${PHP_VER}/mods-available/opcache-custom.ini > /dev/null << 'EOF'
; OPcache configuration
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.save_comments=1
opcache.validate_timestamps=1
EOF
    
    # Configure Xdebug for development
    echo "🐛 Configuring Xdebug..."
    sudo tee /etc/php/${PHP_VER}/mods-available/xdebug-custom.ini > /dev/null << 'EOF'
; Xdebug configuration
xdebug.mode=debug,develop
xdebug.start_with_request=trigger
xdebug.client_host=localhost
xdebug.client_port=9003
xdebug.log=/tmp/xdebug.log
xdebug.idekey=VSCODE
EOF
    
    # Restart PHP-FPM to apply changes
    sudo systemctl restart php${PHP_VER}-fpm
    
    echo "✅ PHP configured successfully!"
}

install_composer() {
    echo "🎼 Installing Composer..."
    
    # Download and install Composer
    cd /tmp
    curl -sS https://getcomposer.org/installer -o composer-setup.php
    
    # Verify installer
    HASH="$(curl -sS https://composer.github.io/installer.sig)"
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    
    # Install Composer globally
    sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
    
    if command -v composer &> /dev/null; then
        echo "✅ Composer installed successfully!"
        COMPOSER_VERSION=$(composer --version | cut -d' ' -f3)
        echo "📋 Composer version: $COMPOSER_VERSION"
        
        # Configure Composer
        configure_composer
    else
        echo "⚠️ Composer installation failed!"
    fi
}

configure_composer() {
    echo "⚙️ Configuring Composer..."
    
    # Set global Composer configuration
    composer config --global process-timeout 2000
    composer config --global cache-ttl 86400
    
    # Create global composer directory
    mkdir -p ~/.composer
    
    echo "✅ Composer configured successfully!"
}

create_php_project_template() {
    echo "📋 Creating PHP project template..."
    
    TEMPLATE_DIR="$HOME/php-project-template"
    if [ ! -d "$TEMPLATE_DIR" ]; then
        mkdir -p "$TEMPLATE_DIR"
        
        # Create composer.json
        cat > "$TEMPLATE_DIR/composer.json" << 'EOF'
{
    "name": "your-name/your-project",
    "description": "A PHP project template",
    "type": "project",
    "require": {
        "php": ">=8.0"
    },
    "require-dev": {
        "phpunit/phpunit": "^9.0",
        "squizlabs/php_codesniffer": "^3.6",
        "phpstan/phpstan": "^1.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\": "tests/"
        }
    },
    "scripts": {
        "test": "phpunit",
        "cs-check": "phpcs",
        "cs-fix": "phpcbf",
        "analyze": "phpstan analyse"
    }
}
EOF
        
        # Create directory structure
        mkdir -p "$TEMPLATE_DIR/src"
        mkdir -p "$TEMPLATE_DIR/tests"
        mkdir -p "$TEMPLATE_DIR/public"
        mkdir -p "$TEMPLATE_DIR/config"
        
        # Create index.php
        cat > "$TEMPLATE_DIR/public/index.php" << 'EOF'
<?php
declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

echo "Hello, PHP World!" . PHP_EOL;
echo "PHP Version: " . PHP_VERSION . PHP_EOL;
EOF
        
        # Create sample class
        cat > "$TEMPLATE_DIR/src/App.php" << 'EOF'
<?php
declare(strict_types=1);

namespace App;

class App
{
    public function run(): string
    {
        return "Application is running!";
    }
}
EOF
        
        # Create sample test
        cat > "$TEMPLATE_DIR/tests/AppTest.php" << 'EOF'
<?php
declare(strict_types=1);

namespace Tests;

use App\App;
use PHPUnit\Framework\TestCase;

class AppTest extends TestCase
{
    public function testRun(): void
    {
        $app = new App();
        $this->assertEquals("Application is running!", $app->run());
    }
}
EOF
        
        # Create phpunit.xml
        cat > "$TEMPLATE_DIR/phpunit.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<phpunit bootstrap="vendor/autoload.php"
         colors="true"
         verbose="true"
         stopOnFailure="false">
    <testsuites>
        <testsuite name="Test Suite">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
    </coverage>
</phpunit>
EOF
        
        # Create .gitignore
        cat > "$TEMPLATE_DIR/.gitignore" << 'EOF'
# Dependencies
/vendor/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Environment
.env
.env.local

# Cache
cache/
tmp/

# Coverage
coverage/
.phpunit.result.cache
EOF
        
        echo "📁 PHP project template created at: $TEMPLATE_DIR"
    fi
}

install_php_tools() {
    echo "🛠️ Installing PHP development tools..."
    
    # Install global Composer packages
    PACKAGES=(
        "phpunit/phpunit"
        "squizlabs/php_codesniffer"
        "phpstan/phpstan"
        "friendsofphp/php-cs-fixer"
        "psy/psysh"
        "laravel/installer"
        "symfony/console"
    )
    
    for package in "${PACKAGES[@]}"; do
        echo "⬇️ Installing $package..."
        composer global require $package --quiet
    done
    
    # Add Composer global bin to PATH
    if ! grep -q "~/.composer/vendor/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.composer/vendor/bin:$PATH"' >> ~/.bashrc
        echo "📝 Added Composer global bin to PATH"
    fi
    
    echo "✅ PHP development tools installed!"
}

setup_php_info_page() {
    echo "📄 Setting up PHP info page..."
    
    # Create phpinfo page
    sudo mkdir -p /var/www/html
    sudo tee /var/www/html/phpinfo.php > /dev/null << 'EOF'
<?php
phpinfo();
?>
EOF
    
    sudo chown www-data:www-data /var/www/html/phpinfo.php
    
    echo "✅ PHP info page created at: /var/www/html/phpinfo.php"
    echo "🌐 Access via: http://localhost/phpinfo.php (if web server is running)"
}

# Function to check if PHP is already installed
check_php_installed() {
    if command -v php &> /dev/null; then
        PHP_VERSION=$(php --version | head -1 | cut -d' ' -f2)
        echo "ℹ️ PHP is already installed"
        echo "   Version: $PHP_VERSION"
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
    echo "           PHP Installation & Configuration"
    echo "============================================================"
    
    # Check if PHP is already installed
    if ! check_php_installed; then
        exit 0
    fi
    
    # Ask about additional features
    read -p "Do you want to install PHP development tools? (y/N): " INSTALL_TOOLS
    read -p "Do you want to create a PHP project template? (y/N): " CREATE_TEMPLATE
    read -p "Do you want to setup PHP info page? (y/N): " SETUP_INFO
    
    # Install PHP
    install_php
    
    if [[ $? -eq 0 ]]; then
        # Install tools if requested
        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            install_php_tools
        fi
        
        # Create template if requested
        if [[ "$CREATE_TEMPLATE" =~ ^[Yy]$ ]]; then
            create_php_project_template
        fi
        
        # Setup info page if requested
        if [[ "$SETUP_INFO" =~ ^[Yy]$ ]]; then
            setup_php_info_page
        fi
        
        echo ""
        echo "✅ All done! PHP is ready to use."
        echo "🚀 Try: php --version"
        echo "🎼 Composer: composer --version"
        echo "📊 Extensions: php -m"
        echo "⚙️ Config: php --ini"
        
        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            echo "🔄 Please restart your shell or run: source ~/.bashrc"
        fi
        
        if [[ "$CREATE_TEMPLATE" =~ ^[Yy]$ ]]; then
            echo "📋 Template: ~/php-project-template/"
        fi
        
    else
        echo "❌ Installation failed. Please check the errors above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi