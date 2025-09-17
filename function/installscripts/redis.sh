#!/bin/bash

# ============================================================
# Redis Installation Script
# Description: Install Redis server with secure configuration
# Author: Anshul Yadav
# ============================================================

install_redis() {
    echo "🔴 Starting Redis installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install Redis server
    echo "⬇️ Installing Redis server..."
    sudo apt install -y redis-server redis-tools
    
    # Start and enable Redis service
    echo "🚀 Starting Redis service..."
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    
    # Check if installation was successful
    if systemctl is-active --quiet redis-server; then
        echo "✅ Redis installed and running successfully!"
        
        # Get Redis version
        REDIS_VERSION=$(redis-server --version | cut -d' ' -f3 | cut -d'=' -f2)
        echo "📋 Redis version: $REDIS_VERSION"
        
        # Configure Redis
        configure_redis
        
        # Test Redis connection
        test_redis_connection
        
        echo ""
        echo "🎉 Redis installation completed successfully!"
        echo "📋 Redis version: $REDIS_VERSION"
        echo "🔧 Service status: $(systemctl is-active redis-server)"
        echo "🌐 Redis is listening on: $(ss -tlnp | grep :6379 | awk '{print $4}' | head -1)"
        
    else
        echo "❌ Redis installation failed!"
        return 1
    fi
}

configure_redis() {
    echo "⚙️ Configuring Redis..."
    
    # Backup original configuration
    sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    
    # Generate Redis password
    REDIS_PASSWORD=$(openssl rand -base64 32)
    
    # Configure Redis settings
    sudo tee /etc/redis/redis.conf > /dev/null << EOF
# Redis Configuration
# Network
bind 127.0.0.1 ::1
port 6379
timeout 300
tcp-keepalive 300

# General
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16

# Snapshotting
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

# Security
requirepass $REDIS_PASSWORD
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "CONFIG_b835729c9f"

# Memory management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Append only file
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Client output buffer limits
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
EOF
    
    # Save Redis password
    echo "Redis Password: $REDIS_PASSWORD" > ~/redis_password.txt
    chmod 600 ~/redis_password.txt
    
    # Set proper permissions
    sudo chown redis:redis /etc/redis/redis.conf
    sudo chmod 640 /etc/redis/redis.conf
    
    # Restart Redis to apply configuration
    sudo systemctl restart redis-server
    
    echo "✅ Redis configured successfully!"
    echo "🔑 Password saved to: ~/redis_password.txt"
}

test_redis_connection() {
    echo "🧪 Testing Redis connection..."
    
    # Get Redis password
    REDIS_PASSWORD=$(grep "Password:" ~/redis_password.txt | cut -d' ' -f3)
    
    # Test basic operations
    redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Redis connection test successful!"
        
        # Test basic operations
        redis-cli -a "$REDIS_PASSWORD" set test_key "Hello Redis" > /dev/null 2>&1
        TEST_VALUE=$(redis-cli -a "$REDIS_PASSWORD" get test_key 2>/dev/null)
        redis-cli -a "$REDIS_PASSWORD" del test_key > /dev/null 2>&1
        
        if [ "$TEST_VALUE" = "Hello Redis" ]; then
            echo "✅ Redis read/write operations working!"
        fi
    else
        echo "⚠️ Redis connection test failed!"
    fi
}

install_redis_cli_tools() {
    echo "🛠️ Installing Redis CLI tools..."
    
    # Install redis-cli if not already installed
    if ! command -v redis-cli &> /dev/null; then
        sudo apt install -y redis-tools
    fi
    
    # Create Redis management script
    sudo tee /usr/local/bin/redis-manager.sh > /dev/null << 'EOF'
#!/bin/bash
# Redis Management Script

REDIS_PASSWORD=$(grep "Password:" ~/redis_password.txt 2>/dev/null | cut -d' ' -f3)

case "$1" in
    status)
        echo "Redis Status:"
        systemctl status redis-server --no-pager
        echo ""
        echo "Redis Info:"
        redis-cli -a "$REDIS_PASSWORD" info server 2>/dev/null | head -10
        ;;
    monitor)
        echo "Monitoring Redis (Ctrl+C to exit):"
        redis-cli -a "$REDIS_PASSWORD" monitor
        ;;
    cli)
        redis-cli -a "$REDIS_PASSWORD"
        ;;
    backup)
        echo "Creating Redis backup..."
        redis-cli -a "$REDIS_PASSWORD" bgsave
        echo "Backup initiated. Check /var/lib/redis/dump.rdb"
        ;;
    flush)
        read -p "Are you sure you want to flush all Redis data? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            redis-cli -a "$REDIS_PASSWORD" eval "return redis.call('flushall')" 0
            echo "All Redis data flushed!"
        fi
        ;;
    *)
        echo "Usage: $0 {status|monitor|cli|backup|flush}"
        echo "  status  - Show Redis status and info"
        echo "  monitor - Monitor Redis commands in real-time"
        echo "  cli     - Open Redis CLI"
        echo "  backup  - Create Redis backup"
        echo "  flush   - Flush all Redis data (dangerous!)"
        ;;
esac
EOF
    
    sudo chmod +x /usr/local/bin/redis-manager.sh
    
    echo "✅ Redis management tools installed!"
    echo "🔧 Use: redis-manager.sh {status|monitor|cli|backup|flush}"
}

setup_redis_monitoring() {
    echo "📊 Setting up Redis monitoring..."
    
    # Create Redis monitoring script
    sudo tee /usr/local/bin/redis-monitor.sh > /dev/null << 'EOF'
#!/bin/bash
# Redis Monitoring Script

REDIS_PASSWORD=$(grep "Password:" ~/redis_password.txt 2>/dev/null | cut -d' ' -f3)
LOG_FILE="/var/log/redis-monitor.log"

# Function to log with timestamp
log_with_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check Redis status
if ! systemctl is-active --quiet redis-server; then
    log_with_timestamp "CRITICAL: Redis service is not running"
    exit 1
fi

# Check Redis connectivity
if ! redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
    log_with_timestamp "CRITICAL: Cannot connect to Redis"
    exit 1
fi

# Get Redis info
REDIS_INFO=$(redis-cli -a "$REDIS_PASSWORD" info 2>/dev/null)
MEMORY_USED=$(echo "$REDIS_INFO" | grep "used_memory_human:" | cut -d':' -f2 | tr -d '\r')
CONNECTED_CLIENTS=$(echo "$REDIS_INFO" | grep "connected_clients:" | cut -d':' -f2 | tr -d '\r')
TOTAL_COMMANDS=$(echo "$REDIS_INFO" | grep "total_commands_processed:" | cut -d':' -f2 | tr -d '\r')

log_with_timestamp "INFO: Memory Used: $MEMORY_USED, Clients: $CONNECTED_CLIENTS, Commands: $TOTAL_COMMANDS"

# Check memory usage (alert if > 80% of maxmemory)
MAXMEMORY=$(redis-cli -a "$REDIS_PASSWORD" config get maxmemory 2>/dev/null | tail -1)
if [ "$MAXMEMORY" != "0" ]; then
    USED_MEMORY_BYTES=$(echo "$REDIS_INFO" | grep "used_memory:" | cut -d':' -f2 | tr -d '\r')
    USAGE_PERCENT=$((USED_MEMORY_BYTES * 100 / MAXMEMORY))
    if [ "$USAGE_PERCENT" -gt 80 ]; then
        log_with_timestamp "WARNING: Memory usage is ${USAGE_PERCENT}%"
    fi
fi
EOF
    
    sudo chmod +x /usr/local/bin/redis-monitor.sh
    
    # Create monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/redis-monitor.sh") | crontab -
    
    echo "✅ Redis monitoring setup completed!"
    echo "📊 Monitor logs: tail -f /var/log/redis-monitor.log"
}

setup_redis_backup() {
    echo "💾 Setting up Redis backup..."
    
    # Create backup directory
    sudo mkdir -p /var/backups/redis
    
    # Create backup script
    sudo tee /usr/local/bin/redis-backup.sh > /dev/null << 'EOF'
#!/bin/bash
# Redis Backup Script

BACKUP_DIR="/var/backups/redis"
DATE=$(date +%Y%m%d_%H%M%S)
REDIS_PASSWORD=$(grep "Password:" ~/redis_password.txt 2>/dev/null | cut -d' ' -f3)

echo "Starting Redis backup: $(date)"

# Create backup using BGSAVE
redis-cli -a "$REDIS_PASSWORD" bgsave > /dev/null 2>&1

# Wait for backup to complete
while [ $(redis-cli -a "$REDIS_PASSWORD" lastsave 2>/dev/null) -eq $(redis-cli -a "$REDIS_PASSWORD" lastsave 2>/dev/null) ]; do
    sleep 1
done

# Copy the dump file
if [ -f /var/lib/redis/dump.rdb ]; then
    cp /var/lib/redis/dump.rdb "$BACKUP_DIR/redis_backup_$DATE.rdb"
    echo "Backup created: $BACKUP_DIR/redis_backup_$DATE.rdb"
else
    echo "Error: Redis dump file not found"
    exit 1
fi

# Compress the backup
gzip "$BACKUP_DIR/redis_backup_$DATE.rdb"
echo "Backup compressed: $BACKUP_DIR/redis_backup_$DATE.rdb.gz"

# Remove backups older than 7 days
find $BACKUP_DIR -name "redis_backup_*.rdb.gz" -mtime +7 -delete

echo "Backup completed: $(date)"
EOF
    
    sudo chmod +x /usr/local/bin/redis-backup.sh
    
    # Create daily backup cron job
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/redis-backup.sh >> /var/log/redis-backup.log 2>&1") | crontab -
    
    echo "✅ Redis backup setup completed!"
    echo "⏰ Daily backup scheduled at 3:00 AM"
}

# Function to check if Redis is already installed
check_redis_installed() {
    if systemctl is-active --quiet redis-server; then
        REDIS_VERSION=$(redis-server --version 2>/dev/null | cut -d' ' -f3 | cut -d'=' -f2)
        echo "ℹ️ Redis is already installed and running"
        echo "   Version: $REDIS_VERSION"
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
    echo "           Redis Server Installer"
    echo "============================================================"
    
    # Check if Redis is already installed
    if ! check_redis_installed; then
        exit 0
    fi
    
    # Ask about additional features
    read -p "Do you want to install Redis CLI management tools? (y/N): " INSTALL_TOOLS
    read -p "Do you want to setup Redis monitoring? (y/N): " SETUP_MONITORING
    read -p "Do you want to setup automated backups? (y/N): " SETUP_BACKUP
    
    # Install Redis
    install_redis
    
    if [[ $? -eq 0 ]]; then
        # Install CLI tools if requested
        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            install_redis_cli_tools
        fi
        
        # Setup monitoring if requested
        if [[ "$SETUP_MONITORING" =~ ^[Yy]$ ]]; then
            setup_redis_monitoring
        fi
        
        # Setup backup if requested
        if [[ "$SETUP_BACKUP" =~ ^[Yy]$ ]]; then
            setup_redis_backup
        fi
        
        echo ""
        echo "✅ All done! Redis is ready to use."
        echo "🔑 Password saved in: ~/redis_password.txt"
        echo "🚀 Connect: redis-cli -a \$(cat ~/redis_password.txt | cut -d' ' -f3)"
        echo "📊 Status: systemctl status redis-server"
        
        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            echo "🛠️ Management: redis-manager.sh status"
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