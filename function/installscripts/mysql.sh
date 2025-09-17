#!/bin/bash

# ============================================================
# MySQL/MariaDB Installation Script
# Description: Install MySQL or MariaDB with secure configuration
# Author: Anshul Yadav
# ============================================================

install_mysql() {
    echo "🗄️ Starting MySQL installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install MySQL server
    echo "⬇️ Installing MySQL server..."
    sudo apt install -y mysql-server mysql-client
    
    # Start and enable MySQL service
    echo "🚀 Starting MySQL service..."
    sudo systemctl start mysql
    sudo systemctl enable mysql
    
    # Check if installation was successful
    if systemctl is-active --quiet mysql; then
        echo "✅ MySQL installed and running successfully!"
        
        # Get MySQL version
        MYSQL_VERSION=$(mysql --version | cut -d' ' -f3 | cut -d',' -f1)
        echo "📋 MySQL version: $MYSQL_VERSION"
        
        # Secure MySQL installation
        secure_mysql_installation
        
        # Create sample database and user
        create_sample_database
        
        echo ""
        echo "🎉 MySQL installation completed successfully!"
        echo "📋 MySQL version: $MYSQL_VERSION"
        echo "🔧 Service status: $(systemctl is-active mysql)"
        echo "🌐 MySQL is listening on: $(ss -tlnp | grep :3306 | awk '{print $4}' | head -1)"
        
    else
        echo "❌ MySQL installation failed!"
        return 1
    fi
}

install_mariadb() {
    echo "🗄️ Starting MariaDB installation..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt update
    
    # Install MariaDB server
    echo "⬇️ Installing MariaDB server..."
    sudo apt install -y mariadb-server mariadb-client
    
    # Start and enable MariaDB service
    echo "🚀 Starting MariaDB service..."
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    
    # Check if installation was successful
    if systemctl is-active --quiet mariadb; then
        echo "✅ MariaDB installed and running successfully!"
        
        # Get MariaDB version
        MARIADB_VERSION=$(mysql --version | cut -d' ' -f6 | cut -d',' -f1)
        echo "📋 MariaDB version: $MARIADB_VERSION"
        
        # Secure MariaDB installation
        secure_mariadb_installation
        
        # Create sample database and user
        create_sample_database
        
        echo ""
        echo "🎉 MariaDB installation completed successfully!"
        echo "📋 MariaDB version: $MARIADB_VERSION"
        echo "🔧 Service status: $(systemctl is-active mariadb)"
        echo "🌐 MariaDB is listening on: $(ss -tlnp | grep :3306 | awk '{print $4}' | head -1)"
        
    else
        echo "❌ MariaDB installation failed!"
        return 1
    fi
}

secure_mysql_installation() {
    echo "🔒 Securing MySQL installation..."
    
    # Generate a random root password
    ROOT_PASSWORD=$(openssl rand -base64 32)
    
    # Set root password and secure installation
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PASSWORD';"
    mysql -u root -p"$ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='';"
    mysql -u root -p"$ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -u root -p"$ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS test;"
    mysql -u root -p"$ROOT_PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -u root -p"$ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
    
    # Save root password to file
    echo "📝 Saving MySQL root password..."
    echo "MySQL Root Password: $ROOT_PASSWORD" > ~/mysql_root_password.txt
    chmod 600 ~/mysql_root_password.txt
    
    echo "✅ MySQL secured successfully!"
    echo "🔑 Root password saved to: ~/mysql_root_password.txt"
}

secure_mariadb_installation() {
    echo "🔒 Securing MariaDB installation..."
    
    # Generate a random root password
    ROOT_PASSWORD=$(openssl rand -base64 32)
    
    # Set root password and secure installation
    mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$ROOT_PASSWORD');"
    mysql -u root -p"$ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='';"
    mysql -u root -p"$ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -u root -p"$ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS test;"
    mysql -u root -p"$ROOT_PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -u root -p"$ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
    
    # Save root password to file
    echo "📝 Saving MariaDB root password..."
    echo "MariaDB Root Password: $ROOT_PASSWORD" > ~/mariadb_root_password.txt
    chmod 600 ~/mariadb_root_password.txt
    
    echo "✅ MariaDB secured successfully!"
    echo "🔑 Root password saved to: ~/mariadb_root_password.txt"
}

create_sample_database() {
    echo "🗃️ Creating sample database and user..."
    
    # Read root password from file
    if [ -f ~/mysql_root_password.txt ]; then
        ROOT_PASSWORD=$(grep "Password:" ~/mysql_root_password.txt | cut -d' ' -f4)
    elif [ -f ~/mariadb_root_password.txt ]; then
        ROOT_PASSWORD=$(grep "Password:" ~/mariadb_root_password.txt | cut -d' ' -f4)
    else
        echo "⚠️ Root password file not found, skipping sample database creation"
        return
    fi
    
    # Generate sample user password
    SAMPLE_PASSWORD=$(openssl rand -base64 16)
    
    # Create sample database and user
    mysql -u root -p"$ROOT_PASSWORD" << EOF
CREATE DATABASE IF NOT EXISTS sampledb;
CREATE USER IF NOT EXISTS 'sampleuser'@'localhost' IDENTIFIED BY '$SAMPLE_PASSWORD';
GRANT ALL PRIVILEGES ON sampledb.* TO 'sampleuser'@'localhost';
FLUSH PRIVILEGES;

USE sampledb;
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, email) VALUES 
('admin', 'admin@example.com'),
('user1', 'user1@example.com');
EOF
    
    # Save sample user credentials
    echo "Sample Database User: sampleuser" >> ~/mysql_credentials.txt
    echo "Sample Database Password: $SAMPLE_PASSWORD" >> ~/mysql_credentials.txt
    echo "Sample Database Name: sampledb" >> ~/mysql_credentials.txt
    chmod 600 ~/mysql_credentials.txt
    
    echo "✅ Sample database 'sampledb' created!"
    echo "👤 Sample user 'sampleuser' created!"
    echo "🔑 Credentials saved to: ~/mysql_credentials.txt"
}

configure_mysql_performance() {
    echo "⚡ Configuring MySQL for better performance..."
    
    # Backup original configuration
    sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup
    
    # Create performance configuration
    sudo tee /etc/mysql/mysql.conf.d/performance.cnf > /dev/null << 'EOF'
[mysqld]
# Performance tuning
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
query_cache_type = 1
query_cache_size = 32M
max_connections = 200
thread_cache_size = 8
table_open_cache = 2000
tmp_table_size = 32M
max_heap_table_size = 32M

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_queries_not_using_indexes = 1
EOF
    
    # Restart MySQL to apply changes
    sudo systemctl restart mysql || sudo systemctl restart mariadb
    
    echo "✅ Performance configuration applied!"
}

setup_mysql_backup() {
    echo "💾 Setting up MySQL backup script..."
    
    # Create backup directory
    sudo mkdir -p /var/backups/mysql
    
    # Create backup script
    sudo tee /usr/local/bin/mysql-backup.sh > /dev/null << 'EOF'
#!/bin/bash
# MySQL Backup Script

BACKUP_DIR="/var/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
DATABASES=$(mysql -u root -p"$(grep 'Password:' ~/mysql_root_password.txt 2>/dev/null | cut -d' ' -f4 || grep 'Password:' ~/mariadb_root_password.txt 2>/dev/null | cut -d' ' -f4)" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

for db in $DATABASES; do
    echo "Backing up database: $db"
    mysqldump -u root -p"$(grep 'Password:' ~/mysql_root_password.txt 2>/dev/null | cut -d' ' -f4 || grep 'Password:' ~/mariadb_root_password.txt 2>/dev/null | cut -d' ' -f4)" --single-transaction --routines --triggers "$db" > "$BACKUP_DIR/${db}_${DATE}.sql"
done

# Remove backups older than 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete

echo "Backup completed: $(date)"
EOF
    
    sudo chmod +x /usr/local/bin/mysql-backup.sh
    
    # Create daily backup cron job
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mysql-backup.sh >> /var/log/mysql-backup.log 2>&1") | crontab -
    
    echo "✅ Backup script created at: /usr/local/bin/mysql-backup.sh"
    echo "⏰ Daily backup scheduled at 2:00 AM"
}

# Function to check if MySQL/MariaDB is already installed
check_database_installed() {
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        if command -v mysql &> /dev/null; then
            DB_VERSION=$(mysql --version)
            echo "ℹ️ Database server is already installed and running"
            echo "   Version: $DB_VERSION"
            read -p "Do you want to reinstall? (y/N): " REINSTALL
            if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
                return 0
            else
                echo "Installation cancelled."
                return 1
            fi
        fi
    fi
    return 0
}

# Main execution
main() {
    echo "============================================================"
    echo "           MySQL/MariaDB Installer"
    echo "============================================================"
    
    # Check if database is already installed
    if ! check_database_installed; then
        exit 0
    fi
    
    # Ask user to choose between MySQL and MariaDB
    echo "Choose database server:"
    echo "1) MySQL"
    echo "2) MariaDB"
    read -p "Enter your choice (1-2): " DB_CHOICE
    
    # Ask about additional features
    read -p "Do you want to configure performance optimizations? (y/N): " CONFIGURE_PERFORMANCE
    read -p "Do you want to setup automated backups? (y/N): " SETUP_BACKUP
    
    # Install chosen database
    case $DB_CHOICE in
        1)
            install_mysql
            ;;
        2)
            install_mariadb
            ;;
        *)
            echo "Invalid choice. Installing MySQL by default..."
            install_mysql
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        # Configure performance if requested
        if [[ "$CONFIGURE_PERFORMANCE" =~ ^[Yy]$ ]]; then
            configure_mysql_performance
        fi
        
        # Setup backup if requested
        if [[ "$SETUP_BACKUP" =~ ^[Yy]$ ]]; then
            setup_mysql_backup
        fi
        
        echo ""
        echo "✅ All done! Database server is ready to use."
        echo "🔑 Check credentials in: ~/mysql_credentials.txt or ~/mariadb_root_password.txt"
        echo "🚀 Connect: mysql -u root -p"
        echo "📊 Status: systemctl status mysql (or mariadb)"
        
    else
        echo "❌ Installation failed. Please check the errors above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi