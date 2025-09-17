#!/bin/bash

# ============================================================
# Node.js Installation Script
# Description: Install latest LTS Node.js with npm and version management
# Author: Anshul Yadav
# ============================================================

install_nodejs() {
    echo "🟢 Starting Node.js installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install prerequisites
    echo "📋 Installing prerequisites..."
    sudo apt install -y curl software-properties-common
    
    # Get latest LTS version
    echo "🔍 Fetching latest LTS version..."
    NODE_VERSION=$(curl -s https://nodejs.org/dist/index.json | grep -o '"version":"v[0-9]*\.[0-9]*\.[0-9]*"' | head -1 | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*')
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
    
    if [ -z "$NODE_MAJOR" ]; then
        echo "⚠️ Could not fetch latest version, using Node.js 20"
        NODE_MAJOR="20"
    fi
    
    echo "📋 Installing Node.js $NODE_MAJOR (LTS)..."
    
    # Add NodeSource repository
    echo "📂 Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | sudo -E bash -
    
    # Install Node.js
    echo "⬇️ Installing Node.js..."
    sudo apt install -y nodejs
    
    # Check if installation was successful
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        echo "✅ Node.js installed successfully!"
        
        # Get installed versions
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)
        echo "📋 Node.js version: $NODE_VERSION"
        echo "📋 npm version: $NPM_VERSION"
        
        # Install useful global packages
        install_global_packages
        
        # Setup npm configuration
        setup_npm_config
        
        echo ""
        echo "🎉 Node.js installation completed successfully!"
        echo "📋 Node.js: $NODE_VERSION"
        echo "📋 npm: $NPM_VERSION"
        echo "📁 Global packages location: $(npm root -g)"
        echo "🔧 npm cache location: $(npm config get cache)"
        
    else
        echo "❌ Node.js installation failed!"
        return 1
    fi
}

install_global_packages() {
    echo "📦 Installing useful global packages..."
    
    # List of useful global packages
    PACKAGES=(
        "yarn"           # Alternative package manager
        "pm2"            # Process manager
        "nodemon"        # Development tool
        "http-server"    # Simple HTTP server
        "live-server"    # Development server with live reload
    )
    
    for package in "${PACKAGES[@]}"; do
        echo "⬇️ Installing $package..."
        npm install -g $package --silent
    done
    
    echo "✅ Global packages installed!"
}

setup_npm_config() {
    echo "⚙️ Setting up npm configuration..."
    
    # Set npm to use a faster registry (optional)
    # npm config set registry https://registry.npmjs.org/
    
    # Set npm cache directory
    npm config set cache ~/.npm-cache
    
    # Set npm prefix for global packages (if not root)
    if [[ $EUID -ne 0 ]]; then
        mkdir -p ~/.npm-global
        npm config set prefix ~/.npm-global
        
        # Add to PATH if not already there
        if ! grep -q "~/.npm-global/bin" ~/.bashrc; then
            echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
            echo "📝 Added npm global bin to PATH in ~/.bashrc"
        fi
    fi
    
    echo "✅ npm configuration completed!"
}

install_nvm() {
    echo "🔧 Installing NVM (Node Version Manager)..."
    
    # Download and install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Source nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    if command -v nvm &> /dev/null; then
        echo "✅ NVM installed successfully!"
        echo "🔧 Usage: nvm install node (latest), nvm install --lts (LTS), nvm use <version>"
    else
        echo "⚠️ NVM installation may need a shell restart"
    fi
}

# Function to check if Node.js is already installed
check_nodejs_installed() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)
        echo "ℹ️ Node.js is already installed"
        echo "   Node.js: $NODE_VERSION"
        echo "   npm: $NPM_VERSION"
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
    echo "           Node.js Latest LTS Installer"
    echo "============================================================"
    
    # Check if Node.js is already installed
    if ! check_nodejs_installed; then
        exit 0
    fi
    
    # Ask about NVM installation
    read -p "Do you want to install NVM (Node Version Manager) as well? (y/N): " INSTALL_NVM
    
    # Install Node.js
    install_nodejs
    
    if [[ $? -eq 0 ]]; then
        # Install NVM if requested
        if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
            install_nvm
        fi
        
        echo ""
        echo "✅ All done! Node.js is ready to use."
        echo "🚀 Try: node --version && npm --version"
        
        if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
            echo "🔄 Please restart your shell or run: source ~/.bashrc"
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