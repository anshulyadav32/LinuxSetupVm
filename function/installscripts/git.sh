#!/bin/bash

# ============================================================
# Git Installation Script
# Description: Install Git with configuration helpers and useful tools
# Author: Anshul Yadav
# ============================================================

install_git() {
    echo "📚 Starting Git installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install Git and related tools
    echo "⬇️ Installing Git and related tools..."
    sudo apt install -y \
        git \
        git-lfs \
        gitk \
        git-gui \
        tig \
        curl \
        wget
    
    # Check if installation was successful
    if command -v git &> /dev/null; then
        echo "✅ Git installed successfully!"
        
        # Get Git version
        GIT_VERSION=$(git --version | cut -d' ' -f3)
        echo "📋 Git version: $GIT_VERSION"
        
        # Configure Git
        configure_git
        
        # Setup Git aliases
        setup_git_aliases
        
        # Install additional Git tools
        install_git_tools
        
        echo ""
        echo "🎉 Git installation completed successfully!"
        echo "📋 Git version: $GIT_VERSION"
        echo "⚙️ Configuration: git config --list"
        
    else
        echo "❌ Git installation failed!"
        return 1
    fi
}

configure_git() {
    echo "⚙️ Configuring Git..."
    
    # Get user information
    read -p "Enter your Git username: " GIT_USERNAME
    read -p "Enter your Git email: " GIT_EMAIL
    
    # Set global Git configuration
    git config --global user.name "$GIT_USERNAME"
    git config --global user.email "$GIT_EMAIL"
    
    # Set default branch name
    git config --global init.defaultBranch main
    
    # Set default editor
    git config --global core.editor "nano"
    
    # Set merge tool
    git config --global merge.tool vimdiff
    
    # Set push behavior
    git config --global push.default simple
    
    # Set pull behavior
    git config --global pull.rebase false
    
    # Enable colored output
    git config --global color.ui auto
    git config --global color.branch auto
    git config --global color.diff auto
    git config --global color.status auto
    
    # Set line ending handling
    git config --global core.autocrlf input
    git config --global core.safecrlf true
    
    # Set credential helper
    git config --global credential.helper store
    
    # Set file permissions
    git config --global core.filemode false
    
    echo "✅ Git configured successfully!"
    echo "👤 User: $GIT_USERNAME <$GIT_EMAIL>"
}

setup_git_aliases() {
    echo "🔗 Setting up Git aliases..."
    
    # Useful Git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.df diff
    git config --global alias.lg "log --oneline --graph --decorate --all"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.visual "!gitk"
    git config --global alias.amend "commit --amend"
    git config --global alias.undo "reset --soft HEAD~1"
    git config --global alias.stash-all "stash save --include-untracked"
    git config --global alias.glog "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
    git config --global alias.find "log --pretty=\"format:%Cgreen%H %Cblue%s\" --name-status --grep"
    git config --global alias.contributors "shortlog --summary --numbered"
    
    echo "✅ Git aliases configured!"
}

install_git_tools() {
    echo "🛠️ Installing additional Git tools..."
    
    # Install GitHub CLI if not already installed
    if ! command -v gh &> /dev/null; then
        echo "⬇️ Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh
        
        if command -v gh &> /dev/null; then
            echo "✅ GitHub CLI installed successfully!"
            GH_VERSION=$(gh --version | head -1 | cut -d' ' -f3)
            echo "📋 GitHub CLI version: $GH_VERSION"
        fi
    fi
    
    # Install Git Flow if available
    if apt-cache show git-flow &> /dev/null; then
        echo "⬇️ Installing Git Flow..."
        sudo apt install -y git-flow
        echo "✅ Git Flow installed!"
    fi
    
    echo "✅ Additional Git tools installed!"
}

create_gitignore_templates() {
    echo "📋 Creating .gitignore templates..."
    
    TEMPLATES_DIR="$HOME/.gitignore-templates"
    mkdir -p "$TEMPLATES_DIR"
    
    # Python .gitignore
    cat > "$TEMPLATES_DIR/Python.gitignore" << 'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
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

# PyInstaller
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# Jupyter Notebook
.ipynb_checkpoints

# pyenv
.python-version

# celery beat schedule file
celerybeat-schedule

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json
EOF
    
    # Node.js .gitignore
    cat > "$TEMPLATES_DIR/Node.gitignore" << 'EOF'
# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov

# Coverage directory used by tools like istanbul
coverage

# nyc test coverage
.nyc_output

# Grunt intermediate storage (https://gruntjs.com/creating-plugins#storing-task-files)
.grunt

# Bower dependency directory (https://bower.io/)
bower_components

# node-waf configuration
.lock-wscript

# Compiled binary addons (https://nodejs.org/api/addons.html)
build/Release

# Dependency directories
node_modules/
jspm_packages/

# TypeScript v1 declaration files
typings/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# dotenv environment variables file
.env

# next.js build output
.next

# nuxt.js build output
.nuxt

# vuepress build output
.vuepress/dist

# Serverless directories
.serverless
EOF
    
    # General .gitignore
    cat > "$TEMPLATES_DIR/General.gitignore" << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*~
*.swp
*.swo
.vscode/
.idea/
*.sublime-project
*.sublime-workspace

# Temporary files
*.tmp
*.temp
*.bak
*.backup

# Log files
*.log

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build directories
build/
dist/
out/
EOF
    
    echo "✅ .gitignore templates created in: $TEMPLATES_DIR"
}

setup_git_hooks() {
    echo "🪝 Setting up Git hooks templates..."
    
    HOOKS_DIR="$HOME/.git-hooks-templates"
    mkdir -p "$HOOKS_DIR"
    
    # Pre-commit hook template
    cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook template

echo "Running pre-commit checks..."

# Check for merge conflict markers
if grep -r "<<<<<<< HEAD" .; then
    echo "Error: Merge conflict markers found!"
    exit 1
fi

# Check for TODO/FIXME comments (optional)
# if grep -r "TODO\|FIXME" --include="*.py" --include="*.js" --include="*.sh" .; then
#     echo "Warning: TODO/FIXME comments found"
# fi

echo "Pre-commit checks passed!"
EOF
    
    # Pre-push hook template
    cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Pre-push hook template

echo "Running pre-push checks..."

# Run tests (uncomment and modify as needed)
# if [ -f "package.json" ]; then
#     npm test
# elif [ -f "requirements.txt" ]; then
#     python -m pytest
# fi

echo "Pre-push checks passed!"
EOF
    
    # Commit message template
    cat > "$HOOKS_DIR/commit-msg" << 'EOF'
#!/bin/bash
# Commit message hook template

commit_regex='^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Format: type(scope): description"
    echo "Types: feat, fix, docs, style, refactor, test, chore"
    echo "Example: feat(auth): add login functionality"
    exit 1
fi
EOF
    
    chmod +x "$HOOKS_DIR"/*
    
    echo "✅ Git hooks templates created in: $HOOKS_DIR"
    echo "💡 To use: cp $HOOKS_DIR/* .git/hooks/ (in your project)"
}

create_git_helper_scripts() {
    echo "📜 Creating Git helper scripts..."
    
    # Git status for all repositories
    sudo tee /usr/local/bin/git-status-all > /dev/null << 'EOF'
#!/bin/bash
# Check Git status for all repositories in current directory

find . -name ".git" -type d | while read gitdir; do
    repo=$(dirname "$gitdir")
    echo "=== $repo ==="
    cd "$repo"
    if [ -n "$(git status --porcelain)" ]; then
        git status --short
    else
        echo "Clean"
    fi
    echo ""
    cd - > /dev/null
done
EOF
    
    # Git pull for all repositories
    sudo tee /usr/local/bin/git-pull-all > /dev/null << 'EOF'
#!/bin/bash
# Pull latest changes for all repositories in current directory

find . -name ".git" -type d | while read gitdir; do
    repo=$(dirname "$gitdir")
    echo "=== Pulling $repo ==="
    cd "$repo"
    git pull
    echo ""
    cd - > /dev/null
done
EOF
    
    # Git branch cleanup
    sudo tee /usr/local/bin/git-cleanup > /dev/null << 'EOF'
#!/bin/bash
# Clean up merged branches

echo "Cleaning up merged branches..."
git branch --merged | grep -v "\*\|main\|master\|develop" | xargs -n 1 git branch -d
echo "Cleanup completed!"
EOF
    
    sudo chmod +x /usr/local/bin/git-*
    
    echo "✅ Git helper scripts created!"
    echo "🔧 Available commands: git-status-all, git-pull-all, git-cleanup"
}

# Function to check if Git is already installed
check_git_installed() {
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | cut -d' ' -f3)
        echo "ℹ️ Git is already installed"
        echo "   Version: $GIT_VERSION"
        read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
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
    echo "           Git Installation & Configuration"
    echo "============================================================"
    
    # Check if Git is already installed
    if ! check_git_installed; then
        exit 0
    fi
    
    # Ask about additional features
    read -p "Do you want to create .gitignore templates? (y/N): " CREATE_TEMPLATES
    read -p "Do you want to setup Git hooks templates? (y/N): " SETUP_HOOKS
    read -p "Do you want to create Git helper scripts? (y/N): " CREATE_HELPERS
    
    # Install Git
    install_git
    
    if [[ $? -eq 0 ]]; then
        # Create templates if requested
        if [[ "$CREATE_TEMPLATES" =~ ^[Yy]$ ]]; then
            create_gitignore_templates
        fi
        
        # Setup hooks if requested
        if [[ "$SETUP_HOOKS" =~ ^[Yy]$ ]]; then
            setup_git_hooks
        fi
        
        # Create helpers if requested
        if [[ "$CREATE_HELPERS" =~ ^[Yy]$ ]]; then
            create_git_helper_scripts
        fi
        
        echo ""
        echo "✅ All done! Git is ready to use."
        echo "🚀 Try: git --version"
        echo "⚙️ Config: git config --list"
        echo "🔗 Aliases: git st, git co, git br, git lg"
        
        if command -v gh &> /dev/null; then
            echo "🐙 GitHub CLI: gh auth login"
        fi
        
        if [[ "$CREATE_TEMPLATES" =~ ^[Yy]$ ]]; then
            echo "📋 Templates: ~/.gitignore-templates/"
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