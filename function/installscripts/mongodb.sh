#!/bin/bash

# ============================================================
# MongoDB Installation Script
# Description: Install and configure MongoDB with security
# Author: Anshul Yadav
# ============================================================

check_mongodb_installed() {
    if systemctl is-active --quiet mongod; then
        echo "⚠️ MongoDB is already installed and running!"
        mongod --version
        read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
        if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

install_mongodb() {
    echo "🍃 Installing MongoDB..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install dependencies
    echo "⬇️ Installing dependencies..."
    sudo apt install -y wget curl gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release
    
    # Add MongoDB GPG key
    echo "🔑 Adding MongoDB GPG key..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    
    # Add MongoDB repository
    echo "📦 Adding MongoDB repository..."
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    
    # Update package list again
    sudo apt update
    
    # Install MongoDB
    echo "⬇️ Installing MongoDB..."
    sudo apt install -y mongodb-org
    
    # Hold MongoDB packages to prevent unintended upgrades
    echo "📌 Holding MongoDB packages..."
    echo "mongodb-org hold" | sudo dpkg --set-selections
    echo "mongodb-org-database hold" | sudo dpkg --set-selections
    echo "mongodb-org-server hold" | sudo dpkg --set-selections
    echo "mongodb-mongosh hold" | sudo dpkg --set-selections
    echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
    echo "mongodb-org-tools hold" | sudo dpkg --set-selections
    
    # Start and enable MongoDB
    sudo systemctl start mongod
    sudo systemctl enable mongod
    
    echo "✅ MongoDB installed and started!"
}

configure_security() {
    echo "🔒 Configuring MongoDB security..."
    
    # Create MongoDB configuration backup
    sudo cp /etc/mongod.conf /etc/mongod.conf.backup
    
    # Configure MongoDB with security settings
    sudo tee /etc/mongod.conf > /dev/null << 'EOF'
# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where to store data
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# Where to write logging data
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

# Network interfaces
net:
  port: 27017
  bindIp: 127.0.0.1

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid

# Security
security:
  authorization: enabled

# Operation profiling
operationProfiling:
  slowOpThresholdMs: 100

# Replication (uncomment for replica sets)
#replication:
#  replSetName: "rs0"

# Sharding (uncomment for sharding)
#sharding:
#  clusterRole: configsvr
EOF
    
    # Restart MongoDB to apply configuration
    sudo systemctl restart mongod
    
    # Wait for MongoDB to start
    sleep 5
    
    echo "✅ Security configuration applied!"
}

create_admin_user() {
    echo "👤 Creating MongoDB admin user..."
    
    # Generate random password
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    
    # Create admin user
    mongosh --eval "
    use admin
    db.createUser({
      user: 'admin',
      pwd: '$ADMIN_PASSWORD',
      roles: [
        { role: 'userAdminAnyDatabase', db: 'admin' },
        { role: 'readWriteAnyDatabase', db: 'admin' },
        { role: 'dbAdminAnyDatabase', db: 'admin' },
        { role: 'clusterAdmin', db: 'admin' }
      ]
    })
    "
    
    # Save credentials
    echo "📝 Saving admin credentials..."
    cat > ~/mongodb-credentials.txt << EOF
MongoDB Admin Credentials
========================
Username: admin
Password: $ADMIN_PASSWORD
Connection: mongodb://admin:$ADMIN_PASSWORD@localhost:27017/admin

Keep this file secure and delete it after noting the credentials!
EOF
    
    chmod 600 ~/mongodb-credentials.txt
    
    echo "✅ Admin user created!"
    echo "📄 Credentials saved to: ~/mongodb-credentials.txt"
}

create_database_user() {
    echo "🗄️ Creating application database and user..."
    
    read -p "Enter database name (default: myapp): " DB_NAME
    DB_NAME=${DB_NAME:-myapp}
    
    read -p "Enter username (default: appuser): " DB_USER
    DB_USER=${DB_USER:-appuser}
    
    # Generate random password
    DB_PASSWORD=$(openssl rand -base64 24)
    
    # Get admin password
    ADMIN_PASSWORD=$(grep "Password:" ~/mongodb-credentials.txt | cut -d' ' -f2)
    
    # Create database and user
    mongosh --eval "
    use admin
    db.auth('admin', '$ADMIN_PASSWORD')
    use $DB_NAME
    db.createUser({
      user: '$DB_USER',
      pwd: '$DB_PASSWORD',
      roles: [
        { role: 'readWrite', db: '$DB_NAME' }
      ]
    })
    "
    
    # Save application credentials
    cat >> ~/mongodb-credentials.txt << EOF

Application Database Credentials
===============================
Database: $DB_NAME
Username: $DB_USER
Password: $DB_PASSWORD
Connection: mongodb://$DB_USER:$DB_PASSWORD@localhost:27017/$DB_NAME
EOF
    
    echo "✅ Database '$DB_NAME' and user '$DB_USER' created!"
}

install_mongodb_tools() {
    echo "🛠️ Installing MongoDB tools..."
    
    # Install MongoDB Compass (GUI)
    read -p "Install MongoDB Compass (GUI tool)? (Y/n): " INSTALL_COMPASS
    if [[ ! "$INSTALL_COMPASS" =~ ^[Nn]$ ]]; then
        echo "⬇️ Installing MongoDB Compass..."
        wget https://downloads.mongodb.com/compass/mongodb-compass_1.40.4_amd64.deb
        sudo dpkg -i mongodb-compass_1.40.4_amd64.deb
        sudo apt-get install -f -y
        rm mongodb-compass_1.40.4_amd64.deb
        echo "✅ MongoDB Compass installed!"
    fi
    
    # Install Studio 3T (alternative GUI)
    read -p "Install Studio 3T (alternative GUI)? (y/N): " INSTALL_STUDIO3T
    if [[ "$INSTALL_STUDIO3T" =~ ^[Yy]$ ]]; then
        echo "⬇️ Installing Studio 3T..."
        wget https://download.studio3t.com/studio-3t/linux/2023.8.1/studio-3t-linux-x64.deb
        sudo dpkg -i studio-3t-linux-x64.deb
        sudo apt-get install -f -y
        rm studio-3t-linux-x64.deb
        echo "✅ Studio 3T installed!"
    fi
    
    echo "✅ MongoDB tools installation completed!"
}

create_management_scripts() {
    echo "📜 Creating MongoDB management scripts..."
    
    mkdir -p ~/bin
    
    # MongoDB status script
    cat > ~/bin/mongo-status << 'EOF'
#!/bin/bash
echo "🍃 MongoDB Status"
echo "================"
systemctl status mongod --no-pager
echo ""
echo "📊 Database Stats:"
mongosh --quiet --eval "
use admin
db.auth('admin', process.env.MONGO_ADMIN_PASS || 'your-admin-password')
print('Databases:')
db.adminCommand('listDatabases').databases.forEach(db => print('  - ' + db.name + ' (' + (db.sizeOnDisk/1024/1024).toFixed(2) + ' MB)'))
"
EOF
    
    # MongoDB backup script
    cat > ~/bin/mongo-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/mongodb-backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -z "$1" ]; then
    echo "Usage: mongo-backup <database-name>"
    echo "Available databases:"
    mongosh --quiet --eval "db.adminCommand('listDatabases').databases.forEach(db => print('  - ' + db.name))"
    exit 1
fi

DATABASE=$1
BACKUP_FILE="$BACKUP_DIR/${DATABASE}_backup_$TIMESTAMP"

echo "🗄️ Backing up database: $DATABASE"
mongodump --db "$DATABASE" --out "$BACKUP_FILE"
tar -czf "$BACKUP_FILE.tar.gz" -C "$BACKUP_DIR" "$(basename "$BACKUP_FILE")"
rm -rf "$BACKUP_FILE"

echo "✅ Backup completed: $BACKUP_FILE.tar.gz"
EOF
    
    # MongoDB restore script
    cat > ~/bin/mongo-restore << 'EOF'
#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: mongo-restore <backup-file.tar.gz> <target-database>"
    exit 1
fi

BACKUP_FILE=$1
TARGET_DB=$2
TEMP_DIR="/tmp/mongo-restore-$$"

echo "📥 Restoring database: $TARGET_DB"
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the database directory
DB_DIR=$(find "$TEMP_DIR" -type d -name "*" | head -1)
mongorestore --db "$TARGET_DB" "$DB_DIR"

rm -rf "$TEMP_DIR"
echo "✅ Restore completed!"
EOF
    
    # MongoDB connection script
    cat > ~/bin/mongo-connect << 'EOF'
#!/bin/bash
echo "🔗 MongoDB Connection Helper"
echo "==========================="

if [ -f ~/mongodb-credentials.txt ]; then
    echo "📄 Available credentials:"
    grep -E "(Username|Database):" ~/mongodb-credentials.txt
    echo ""
fi

echo "Connection examples:"
echo "  mongosh                                    # Local connection"
echo "  mongosh mongodb://username:password@host/db # Remote connection"
echo "  mongosh --username admin --password        # Admin connection"
EOF
    
    chmod +x ~/bin/mongo-*
    
    echo "✅ Management scripts created!"
}

configure_monitoring() {
    echo "📊 Setting up MongoDB monitoring..."
    
    # Create monitoring script
    cat > ~/bin/mongo-monitor << 'EOF'
#!/bin/bash
echo "📊 MongoDB Monitoring"
echo "===================="

# System resources
echo "💾 Memory Usage:"
free -h | grep -E "(Mem|Swap)"

echo ""
echo "💿 Disk Usage:"
df -h | grep -E "(mongodb|/var/lib)"

echo ""
echo "🔄 MongoDB Process:"
ps aux | grep mongod | grep -v grep

echo ""
echo "📈 Connection Stats:"
mongosh --quiet --eval "
use admin
try {
  db.auth('admin', process.env.MONGO_ADMIN_PASS || 'your-admin-password')
  var stats = db.serverStatus()
  print('Current Connections: ' + stats.connections.current)
  print('Available Connections: ' + stats.connections.available)
  print('Total Created: ' + stats.connections.totalCreated)
} catch(e) {
  print('Authentication required for detailed stats')
}
"
EOF
    
    chmod +x ~/bin/mongo-monitor
    
    echo "✅ Monitoring setup completed!"
}

# Main execution
main() {
    echo "============================================================"
    echo "                MongoDB Installation"
    echo "============================================================"
    
    check_mongodb_installed
    
    read -p "Install MongoDB? (Y/n): " INSTALL_MONGO
    read -p "Configure security settings? (Y/n): " CONFIGURE_SECURITY
    read -p "Create admin user? (Y/n): " CREATE_ADMIN
    read -p "Create application database and user? (Y/n): " CREATE_DB_USER
    read -p "Install MongoDB tools (Compass, etc.)? (Y/n): " INSTALL_TOOLS
    read -p "Create management scripts? (Y/n): " CREATE_SCRIPTS
    
    if [[ ! "$INSTALL_MONGO" =~ ^[Nn]$ ]]; then
        install_mongodb
    fi
    
    if [[ ! "$CONFIGURE_SECURITY" =~ ^[Nn]$ ]]; then
        configure_security
    fi
    
    if [[ ! "$CREATE_ADMIN" =~ ^[Nn]$ ]]; then
        create_admin_user
    fi
    
    if [[ ! "$CREATE_DB_USER" =~ ^[Nn]$ ]]; then
        create_database_user
    fi
    
    if [[ ! "$INSTALL_TOOLS" =~ ^[Nn]$ ]]; then
        install_mongodb_tools
    fi
    
    if [[ ! "$CREATE_SCRIPTS" =~ ^[Nn]$ ]]; then
        create_management_scripts
        configure_monitoring
    fi
    
    echo ""
    echo "✅ MongoDB installation and configuration completed!"
    echo ""
    echo "🍃 MongoDB Status:"
    systemctl status mongod --no-pager -l
    echo ""
    echo "🚀 Quick Commands:"
    echo "  sudo systemctl start mongod     # Start MongoDB"
    echo "  sudo systemctl stop mongod      # Stop MongoDB"
    echo "  sudo systemctl restart mongod   # Restart MongoDB"
    echo "  mongosh                         # Connect to MongoDB"
    echo ""
    echo "📜 Management Scripts:"
    echo "  mongo-status                    # Show MongoDB status"
    echo "  mongo-backup <database>         # Backup database"
    echo "  mongo-restore <file> <db>       # Restore database"
    echo "  mongo-connect                   # Connection helper"
    echo "  mongo-monitor                   # System monitoring"
    echo ""
    echo "📁 Important Files:"
    echo "  /etc/mongod.conf                # Configuration file"
    echo "  /var/log/mongodb/mongod.log     # Log file"
    echo "  ~/mongodb-credentials.txt       # Saved credentials"
    echo ""
    echo "🔗 Connection:"
    echo "  Local: mongodb://localhost:27017"
    if [ -f ~/mongodb-credentials.txt ]; then
        echo "  📄 Check ~/mongodb-credentials.txt for user credentials"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi