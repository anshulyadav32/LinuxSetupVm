#!/bin/bash

# ============================================================
# PM2 Process Manager Installation Script
# Description: Install and configure PM2 for Node.js applications
# Author: Anshul Yadav
# ============================================================

check_pm2_installed() {
    if command -v pm2 &> /dev/null; then
        echo "⚠️ PM2 is already installed!"
        pm2 --version
        read -p "Do you want to reinstall? (y/N): " REINSTALL
        if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

install_pm2() {
    echo "📦 Installing PM2 Process Manager..."
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js is required for PM2. Please install Node.js first."
        read -p "Install Node.js now? (Y/n): " INSTALL_NODE
        if [[ ! "$INSTALL_NODE" =~ ^[Nn]$ ]]; then
            # Install Node.js
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        else
            echo "❌ Cannot proceed without Node.js"
            exit 1
        fi
    fi
    
    # Install PM2 globally
    echo "⬇️ Installing PM2..."
    sudo npm install -g pm2@latest
    
    # Install PM2 log rotate
    pm2 install pm2-logrotate
    
    echo "✅ PM2 installed successfully!"
}

configure_pm2() {
    echo "⚙️ Configuring PM2..."
    
    # Set up PM2 startup script
    echo "🚀 Setting up PM2 startup script..."
    pm2 startup
    
    # Configure log rotation
    echo "📝 Configuring log rotation..."
    pm2 set pm2-logrotate:max_size 10M
    pm2 set pm2-logrotate:retain 30
    pm2 set pm2-logrotate:compress true
    pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss
    
    echo "✅ PM2 configured!"
}

create_ecosystem_file() {
    echo "📄 Creating PM2 ecosystem configuration..."
    
    cat > ~/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'app',
      script: './app.js',
      instances: 'max',
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      log_file: './logs/combined.log',
      out_file: './logs/out.log',
      error_file: './logs/error.log',
      log_date_format: 'YYYY-MM-DD HH:mm Z',
      merge_logs: true,
      max_memory_restart: '1G',
      node_args: '--max_old_space_size=1024',
      watch: false,
      ignore_watch: ['node_modules', 'logs'],
      max_restarts: 10,
      min_uptime: '10s'
    }
  ],
  deploy: {
    production: {
      user: 'ubuntu',
      host: 'your-server.com',
      ref: 'origin/main',
      repo: 'git@github.com:username/repository.git',
      path: '/var/www/production',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
      'pre-setup': ''
    }
  }
};
EOF
    
    echo "✅ Ecosystem file created at ~/ecosystem.config.js"
}

create_pm2_scripts() {
    echo "📜 Creating PM2 utility scripts..."
    
    mkdir -p ~/bin
    
    # PM2 status script
    cat > ~/bin/pm2-status << 'EOF'
#!/bin/bash
echo "🔍 PM2 Process Status"
echo "===================="
pm2 status
echo ""
echo "💾 Memory Usage"
pm2 monit --no-interaction
EOF
    
    # PM2 logs script
    cat > ~/bin/pm2-logs << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "📝 All PM2 Logs"
    pm2 logs --lines 50
else
    echo "📝 Logs for: $1"
    pm2 logs "$1" --lines 50
fi
EOF
    
    # PM2 restart all script
    cat > ~/bin/pm2-restart-all << 'EOF'
#!/bin/bash
echo "🔄 Restarting all PM2 processes..."
pm2 restart all
pm2 status
EOF
    
    # PM2 backup script
    cat > ~/bin/pm2-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/pm2-backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pm2 save
cp ~/.pm2/dump.pm2 "$BACKUP_DIR/dump_$TIMESTAMP.pm2"
echo "✅ PM2 processes backed up to: $BACKUP_DIR/dump_$TIMESTAMP.pm2"
EOF
    
    chmod +x ~/bin/pm2-*
    
    echo "✅ PM2 utility scripts created!"
}

setup_monitoring() {
    echo "📊 Setting up PM2 monitoring..."
    
    # Install PM2 web interface (optional)
    read -p "Install PM2 web monitoring interface? (Y/n): " INSTALL_WEB
    if [[ ! "$INSTALL_WEB" =~ ^[Nn]$ ]]; then
        sudo npm install -g pm2-web
        echo "🌐 PM2 web interface installed. Run 'pm2-web' to start."
    fi
    
    # Set up system monitoring
    echo "⚙️ Configuring system monitoring..."
    pm2 install pm2-server-monit
    
    echo "✅ Monitoring setup completed!"
}

create_sample_app() {
    echo "📱 Creating sample Node.js application..."
    
    read -p "Create a sample Node.js app for testing PM2? (Y/n): " CREATE_SAMPLE
    if [[ ! "$CREATE_SAMPLE" =~ ^[Nn]$ ]]; then
        mkdir -p ~/pm2-sample-app
        cd ~/pm2-sample-app
        
        # Create package.json
        cat > package.json << 'EOF'
{
  "name": "pm2-sample-app",
  "version": "1.0.0",
  "description": "Sample Node.js app for PM2 testing",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
        
        # Create sample app
        cat > app.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from PM2 Sample App!',
    pid: process.pid,
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    pid: process.pid
  });
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOF
        
        # Install dependencies
        npm install
        
        echo "✅ Sample app created in ~/pm2-sample-app"
        echo "🚀 To start with PM2: cd ~/pm2-sample-app && pm2 start app.js"
    fi
}

# Main execution
main() {
    echo "============================================================"
    echo "              PM2 Process Manager Installation"
    echo "============================================================"
    
    check_pm2_installed
    
    read -p "Install PM2? (Y/n): " INSTALL_PM2
    read -p "Configure PM2 (startup, logs)? (Y/n): " CONFIGURE_PM2
    read -p "Create ecosystem config file? (Y/n): " CREATE_ECOSYSTEM
    read -p "Create utility scripts? (Y/n): " CREATE_SCRIPTS
    read -p "Setup monitoring? (Y/n): " SETUP_MONITORING
    
    if [[ ! "$INSTALL_PM2" =~ ^[Nn]$ ]]; then
        install_pm2
    fi
    
    if [[ ! "$CONFIGURE_PM2" =~ ^[Nn]$ ]]; then
        configure_pm2
    fi
    
    if [[ ! "$CREATE_ECOSYSTEM" =~ ^[Nn]$ ]]; then
        create_ecosystem_file
    fi
    
    if [[ ! "$CREATE_SCRIPTS" =~ ^[Nn]$ ]]; then
        create_pm2_scripts
    fi
    
    if [[ ! "$SETUP_MONITORING" =~ ^[Nn]$ ]]; then
        setup_monitoring
    fi
    
    create_sample_app
    
    echo ""
    echo "✅ PM2 installation and configuration completed!"
    echo ""
    echo "🚀 Quick Start Commands:"
    echo "  pm2 start app.js              # Start an app"
    echo "  pm2 start ecosystem.config.js # Start with config"
    echo "  pm2 list                      # List processes"
    echo "  pm2 monit                     # Monitor processes"
    echo "  pm2 logs                      # View logs"
    echo "  pm2 restart all               # Restart all"
    echo "  pm2 stop all                  # Stop all"
    echo "  pm2 save                      # Save process list"
    echo ""
    echo "📊 Utility Scripts:"
    echo "  pm2-status                    # Show status"
    echo "  pm2-logs [app-name]           # Show logs"
    echo "  pm2-restart-all               # Restart all apps"
    echo "  pm2-backup                    # Backup processes"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi