#!/bin/bash

# ============================================================
# Docker Installation Script
# Description: Install latest Docker Engine and Docker Compose
# Author: Anshul Yadav
# ============================================================

install_docker() {
    echo "🐳 Starting Docker installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install prerequisites
    echo "📋 Installing prerequisites..."
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    echo "🔑 Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "📂 Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list again
    sudo apt update
    
    # Install Docker Engine
    echo "⬇️ Installing Docker Engine..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Check if installation was successful
    if command -v docker &> /dev/null; then
        echo "✅ Docker installed successfully!"
        
        # Get installed version
        DOCKER_VERSION=$(docker --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        echo "📋 Docker version: $DOCKER_VERSION"
        
        # Start and enable Docker service
        echo "🔄 Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add current user to docker group
        echo "👤 Adding user to docker group..."
        sudo usermod -aG docker $USER
        
        # Install Docker Compose (standalone)
        install_docker_compose
        
        # Test Docker installation
        echo "🧪 Testing Docker installation..."
        if sudo docker run hello-world &> /dev/null; then
            echo "✅ Docker test successful!"
        else
            echo "⚠️ Docker test failed, but installation completed"
        fi
        
        echo ""
        echo "🎉 Docker installation completed successfully!"
        echo "📋 Docker version: $(docker --version)"
        echo "📋 Docker Compose version: $(docker compose version)"
        echo "⚠️ Please log out and log back in for group changes to take effect"
        echo "🔧 Or run: newgrp docker"
        
    else
        echo "❌ Docker installation failed!"
        return 1
    fi
}

install_docker_compose() {
    echo "🔧 Installing Docker Compose..."
    
    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    if [ -z "$COMPOSE_VERSION" ]; then
        echo "⚠️ Could not fetch latest version, using v2.24.0"
        COMPOSE_VERSION="v2.24.0"
    fi
    
    echo "📋 Installing Docker Compose $COMPOSE_VERSION..."
    
    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose installed successfully!"
    else
        echo "⚠️ Docker Compose installation may have issues"
    fi
}

# Function to check if Docker is already installed
check_docker_installed() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        echo "ℹ️ Docker is already installed (version: $DOCKER_VERSION)"
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
    echo "           Docker Latest Version Installer"
    echo "============================================================"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "⚠️ Running as root. This is not recommended."
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi
    
    # Check if Docker is already installed
    if ! check_docker_installed; then
        exit 0
    fi
    
    # Install Docker
    install_docker
    
    if [[ $? -eq 0 ]]; then
        echo "✅ All done! Docker is ready to use."
        echo "🚀 Try: docker run hello-world"
    else
        echo "❌ Installation failed. Please check the errors above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi