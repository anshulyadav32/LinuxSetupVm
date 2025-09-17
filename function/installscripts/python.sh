#!/bin/bash

# ============================================================
# Python Installation Script
# Description: Install latest Python with pip, venv, and development tools
# Author: Anshul Yadav
# ============================================================

install_python() {
    echo "🐍 Starting Python installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install Python and essential packages
    echo "⬇️ Installing Python and essential packages..."
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-setuptools \
        python3-wheel \
        build-essential \
        libssl-dev \
        libffi-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        wget \
        curl \
        llvm \
        libncurses5-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev
    
    # Create symbolic links for easier access
    if ! command -v python &> /dev/null; then
        echo "🔗 Creating python symlink..."
        sudo ln -sf /usr/bin/python3 /usr/bin/python
    fi
    
    if ! command -v pip &> /dev/null; then
        echo "🔗 Creating pip symlink..."
        sudo ln -sf /usr/bin/pip3 /usr/bin/pip
    fi
    
    # Upgrade pip to latest version
    echo "⬆️ Upgrading pip to latest version..."
    python3 -m pip install --upgrade pip
    
    # Check if installation was successful
    if command -v python3 &> /dev/null && command -v pip3 &> /dev/null; then
        echo "✅ Python installed successfully!"
        
        # Get installed versions
        PYTHON_VERSION=$(python3 --version)
        PIP_VERSION=$(pip3 --version | cut -d' ' -f2)
        echo "📋 Python version: $PYTHON_VERSION"
        echo "📋 pip version: $PIP_VERSION"
        
        # Install essential Python packages
        install_essential_packages
        
        # Setup virtual environment tools
        setup_virtualenv_tools
        
        echo ""
        echo "🎉 Python installation completed successfully!"
        echo "📋 Python: $PYTHON_VERSION"
        echo "📋 pip: $PIP_VERSION"
        echo "📁 Python executable: $(which python3)"
        echo "📁 pip executable: $(which pip3)"
        
    else
        echo "❌ Python installation failed!"
        return 1
    fi
}

install_essential_packages() {
    echo "📦 Installing essential Python packages..."
    
    # List of essential packages
    PACKAGES=(
        "virtualenv"        # Virtual environment tool
        "virtualenvwrapper" # Enhanced virtual environment management
        "pipenv"           # Modern dependency management
        "poetry"           # Advanced dependency management
        "wheel"            # Package building tool
        "setuptools"       # Package development utilities
        "requests"         # HTTP library
        "urllib3"          # HTTP client
        "certifi"          # SSL certificates
        "six"              # Python 2/3 compatibility
    )
    
    for package in "${PACKAGES[@]}"; do
        echo "⬇️ Installing $package..."
        pip3 install --user $package --quiet
    done
    
    echo "✅ Essential packages installed!"
}

setup_virtualenv_tools() {
    echo "🛠️ Setting up virtual environment tools..."
    
    # Create a directory for virtual environments
    VENV_DIR="$HOME/.virtualenvs"
    if [ ! -d "$VENV_DIR" ]; then
        mkdir -p "$VENV_DIR"
        echo "📁 Created virtual environments directory: $VENV_DIR"
    fi
    
    # Setup virtualenvwrapper if not already configured
    if ! grep -q "virtualenvwrapper.sh" ~/.bashrc; then
        echo "⚙️ Configuring virtualenvwrapper..."
        cat >> ~/.bashrc << 'EOF'

# Virtualenvwrapper configuration
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
export VIRTUALENVWRAPPER_VIRTUALENV=$HOME/.local/bin/virtualenv
source $HOME/.local/bin/virtualenvwrapper.sh 2>/dev/null || true
EOF
        echo "📝 Added virtualenvwrapper configuration to ~/.bashrc"
    fi
    
    # Create a sample virtual environment
    echo "🧪 Creating sample virtual environment 'myproject'..."
    python3 -m venv "$VENV_DIR/myproject"
    echo "✅ Sample virtual environment created!"
    
    echo "🔧 Virtual environment tools configured!"
}

install_pyenv() {
    echo "🔧 Installing pyenv (Python Version Manager)..."
    
    # Install pyenv dependencies
    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
        libffi-dev liblzma-dev
    
    # Download and install pyenv
    curl https://pyenv.run | bash
    
    # Add pyenv to PATH
    if ! grep -q "pyenv" ~/.bashrc; then
        echo "⚙️ Configuring pyenv..."
        cat >> ~/.bashrc << 'EOF'

# Pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
        echo "📝 Added pyenv configuration to ~/.bashrc"
    fi
    
    # Source the configuration
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    
    if command -v pyenv &> /dev/null; then
        echo "✅ pyenv installed successfully!"
        echo "🔧 Usage: pyenv install 3.11.0, pyenv global 3.11.0, pyenv versions"
    else
        echo "⚠️ pyenv installation may need a shell restart"
    fi
}

create_python_project_template() {
    echo "📋 Creating Python project template..."
    
    TEMPLATE_DIR="$HOME/python-project-template"
    if [ ! -d "$TEMPLATE_DIR" ]; then
        mkdir -p "$TEMPLATE_DIR"
        
        # Create basic project structure
        cat > "$TEMPLATE_DIR/requirements.txt" << 'EOF'
# Production dependencies
requests>=2.28.0
python-dotenv>=0.19.0

# Development dependencies (install with: pip install -r requirements-dev.txt)
EOF
        
        cat > "$TEMPLATE_DIR/requirements-dev.txt" << 'EOF'
# Development dependencies
pytest>=7.0.0
black>=22.0.0
flake8>=4.0.0
mypy>=0.950
pre-commit>=2.17.0
EOF
        
        cat > "$TEMPLATE_DIR/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Main application entry point
"""

def main():
    print("Hello, Python!")

if __name__ == "__main__":
    main()
EOF
        
        cat > "$TEMPLATE_DIR/.gitignore" << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
venv/
env/
ENV/
.venv/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Environment variables
.env
.env.local

# Testing
.pytest_cache/
.coverage
htmlcov/

# OS
.DS_Store
Thumbs.db
EOF
        
        chmod +x "$TEMPLATE_DIR/main.py"
        echo "📁 Python project template created at: $TEMPLATE_DIR"
    fi
}

# Function to check if Python is already installed
check_python_installed() {
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        PIP_VERSION=$(pip3 --version 2>/dev/null | cut -d' ' -f2 || echo "Not installed")
        echo "ℹ️ Python is already installed"
        echo "   Python: $PYTHON_VERSION"
        echo "   pip: $PIP_VERSION"
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
    echo "           Python Latest Installer"
    echo "============================================================"
    
    # Check if Python is already installed
    if ! check_python_installed; then
        exit 0
    fi
    
    # Ask about additional tools
    read -p "Do you want to install pyenv (Python Version Manager)? (y/N): " INSTALL_PYENV
    read -p "Do you want to create a Python project template? (y/N): " CREATE_TEMPLATE
    
    # Install Python
    install_python
    
    if [[ $? -eq 0 ]]; then
        # Install pyenv if requested
        if [[ "$INSTALL_PYENV" =~ ^[Yy]$ ]]; then
            install_pyenv
        fi
        
        # Create project template if requested
        if [[ "$CREATE_TEMPLATE" =~ ^[Yy]$ ]]; then
            create_python_project_template
        fi
        
        echo ""
        echo "✅ All done! Python is ready to use."
        echo "🚀 Try: python3 --version && pip3 --version"
        echo "🧪 Create virtual environment: python3 -m venv myenv"
        echo "🔄 Activate virtual environment: source myenv/bin/activate"
        
        if [[ "$INSTALL_PYENV" =~ ^[Yy]$ ]]; then
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