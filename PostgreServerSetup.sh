#!/bin/bash
# ============================================================
# PostgreSQL Setup with SSL (Let's Encrypt + Fallback) + User/DB
# Author: Anshul Yadav
# ============================================================

set -e

# ===== Auto-detect values =====
DEFAULT_PRIVATE_IP=$(hostname -I | awk '{print $1}')
DEFAULT_PUBLIC_IP4=$(curl -s -4 ifconfig.me || echo "")
DEFAULT_PUBLIC_IP6=$(curl -s -6 ifconfig.me || echo "")
DEFAULT_HOSTNAME=$(hostname -f 2>/dev/null || hostname)

# PostgreSQL paths will be set dynamically based on detected version
PG_HBA=""
PG_CONF=""
SSL_DIR="/etc/ssl/postgresql"

# ============================================================
# Functions
# ============================================================

load_saved_credentials() {
  if [[ -f "$HOME/.db_cred" ]]; then
    echo "💾 Found existing credentials at $HOME/.db_cred"
    source "$HOME/.db_cred"
    echo "  User: $DBUSER"
    echo "  DB:   $DBNAME"
    echo "  Host: $HOST1"
    read -p "Reuse these credentials? (Y/n): " REUSE
    REUSE=${REUSE:-Y}
    if [[ "$REUSE" =~ ^[Yy]$ ]]; then
      USE_SAVED="yes"
    fi
  fi
}

collect_inputs() {
  # ===== User Input with defaults =====
  read -p "Enter PostgreSQL Username [dbuser]: " DBUSER
  DBUSER=${DBUSER:-dbuser}

  read -sp "Enter Password for $DBUSER [autogen]: " DBPASS
  echo
  DBPASS=${DBPASS:-$(openssl rand -hex 12)}

  read -p "Enter Database Name [mydb]: " DBNAME
  DBNAME=${DBNAME:-mydb}

  read -p "Enter Private IP [$DEFAULT_PRIVATE_IP]: " PRIVATE_IP
  PRIVATE_IP=${PRIVATE_IP:-$DEFAULT_PRIVATE_IP}

  read -p "Enter Public IPv4 [$DEFAULT_PUBLIC_IP4]: " PUBLIC_IP4
  PUBLIC_IP4=${PUBLIC_IP4:-$DEFAULT_PUBLIC_IP4}

  read -p "Enter Public IPv6 [$DEFAULT_PUBLIC_IP6]: " PUBLIC_IP6
  PUBLIC_IP6=${PUBLIC_IP6:-$DEFAULT_PUBLIC_IP6}

  read -p "Enter Primary Hostname [$DEFAULT_HOSTNAME]: " HOST1
  HOST1=${HOST1:-$DEFAULT_HOSTNAME}

  read -p "Enter Secondary Hostname (optional): " HOST2

  read -p "Allow Public Access? (y/n) [y]: " PUBLIC
  PUBLIC=${PUBLIC:-y}
}

verify_hostname_mapping() {
  echo
  echo "🔍 Verifying that hostnames resolve to this VM..."

  THIS_IPV4=$(hostname -I | awk '{print $1}')
  THIS_IPV6=$(ip -6 addr show scope global | awk '/inet6/{print $2}' | cut -d/ -f1 | head -n1)

  for H in "$HOST1" "$HOST2"; do
    [[ -z "$H" ]] && continue
    echo -n "Checking $H ... "
    RESOLVED_IPS=$(getent ahosts "$H" | awk '{print $1}' | sort -u)
    if [[ -z "$RESOLVED_IPS" ]]; then
      echo "❌ Does not resolve"
      exit 1
    fi

    MATCHED="no"
    for IP in $RESOLVED_IPS; do
      if [[ "$IP" == "$THIS_IPV4" || "$IP" == "$THIS_IPV6" || "$PUBLIC_IP4" == "$IP" || "$PUBLIC_IP6" == "$IP" ]]; then
        echo "✅ Resolves correctly to $IP"
        MATCHED="yes"
        break
      fi
    done

    if [[ "$MATCHED" == "no" ]]; then
      echo "❌ Hostname resolves, but not to this VM ($RESOLVED_IPS)"
      exit 1
    fi
  done
}

update_pg_hba() {
  echo "🔧 Updating pg_hba.conf for SSL..."
  sudo sed -i '/hostssl all all/d' "$PG_HBA"

  echo "hostssl all all 127.0.0.1/32 md5" | sudo tee -a "$PG_HBA"
  echo "hostssl all all $PRIVATE_IP/32 md5" | sudo tee -a "$PG_HBA"

  if [[ "$PUBLIC" =~ ^[Yy]$ ]]; then
    [[ -n "$PUBLIC_IP4" ]] && echo "hostssl all all $PUBLIC_IP4/32 md5" | sudo tee -a "$PG_HBA"
    [[ -n "$PUBLIC_IP6" ]] && echo "hostssl all all $PUBLIC_IP6/128 md5" | sudo tee -a "$PG_HBA"
    # Allow connections from any IP for external access
    echo "hostssl all all 0.0.0.0/0 md5" | sudo tee -a "$PG_HBA"
    echo "hostssl all all ::/0 md5" | sudo tee -a "$PG_HBA"
  fi

  echo "hostssl all all ::1/128 md5" | sudo tee -a "$PG_HBA"
}

setup_domain_ssl() {
  echo "🔐 Trying Let's Encrypt SSL for domain(s)..."

  if ! command -v certbot >/dev/null; then
    sudo apt update
    sudo apt install -y certbot
  fi

  DOMAIN_ARGS="-d $HOST1"
  [[ -n "$HOST2" ]] && DOMAIN_ARGS="$DOMAIN_ARGS -d $HOST2"

  # Check if port 80 is already in use
  if sudo lsof -i:80 >/dev/null 2>&1; then
    echo "⚠️ Port 80 is in use. Switching to webroot mode."

    if systemctl is-active --quiet apache2; then
      WEBROOT="/var/www/html"
    elif systemctl is-active --quiet nginx; then
      WEBROOT="/usr/share/nginx/html"
    else
      WEBROOT="/var/www/html"
    fi
    sudo mkdir -p "$WEBROOT"

    if sudo certbot certonly --webroot -w "$WEBROOT" $DOMAIN_ARGS \
        --non-interactive --agree-tos -m admin@"$HOST1" --quiet; then
      echo "✅ SSL issued with webroot mode for $HOST1"
      CERT_PATH="/etc/letsencrypt/live/$HOST1"
      SSL_TYPE="Let's Encrypt (webroot)"
    else
      echo "❌ Let's Encrypt webroot mode failed."
      SSL_TYPE="Self-signed"
      USE_LE_SSL="no"
      return 1
    fi
  else
    echo "ℹ️ Port 80 is free. Using standalone mode."
    if sudo certbot certonly --standalone $DOMAIN_ARGS \
        --non-interactive --agree-tos -m admin@"$HOST1" --quiet; then
      echo "✅ SSL issued with standalone mode for $HOST1"
      CERT_PATH="/etc/letsencrypt/live/$HOST1"
      SSL_TYPE="Let's Encrypt (standalone)"
    else
      echo "❌ Let's Encrypt standalone mode failed."
      SSL_TYPE="Self-signed"
      USE_LE_SSL="no"
      return 1
    fi
  fi

  # If we reached here, Let's Encrypt succeeded
  # Fix SSL certificate permissions for PostgreSQL
  sudo chmod 755 "/etc/letsencrypt/live"
  sudo chmod 755 "/etc/letsencrypt/archive"
  sudo chmod 755 "/etc/letsencrypt/live/$HOST1"
  sudo chmod 755 "/etc/letsencrypt/archive/$HOST1"
  sudo chmod 644 "/etc/letsencrypt/archive/$HOST1"/*.pem
  sudo chmod 640 "/etc/letsencrypt/archive/$HOST1"/privkey*.pem
  sudo chgrp postgres "/etc/letsencrypt/archive/$HOST1"/privkey*.pem
  
  # Enable SSL in PostgreSQL config
  sudo sed -i "s|^#*ssl = .*|ssl = on|" "$PG_CONF"
  sudo sed -i "s|^#*ssl_cert_file.*|ssl_cert_file = '$CERT_PATH/fullchain.pem'|" "$PG_CONF"
  sudo sed -i "s|^#*ssl_key_file.*|ssl_key_file = '$CERT_PATH/privkey.pem'|" "$PG_CONF"
  
  # Enable external connections
  sudo sed -i "s|^#*listen_addresses.*|listen_addresses = '*'|" "$PG_CONF"
  
  # Restart PostgreSQL service
  sudo systemctl restart "$PG_SERVICE"
  sleep 2
  
  # Check if PostgreSQL started successfully
  if ! sudo systemctl is-active --quiet "$PG_SERVICE"; then
    echo "❌ PostgreSQL failed to start with Let's Encrypt SSL. Check logs:"
    sudo journalctl -u "$PG_SERVICE" -n 5 --no-pager
    return 1
  fi

  # Renewal hook
  sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat << 'EOF' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-postgres.sh >/dev/null
#!/bin/bash
# Fix parent directory permissions
chmod 755 /etc/letsencrypt/live
chmod 755 /etc/letsencrypt/archive

for domain in /etc/letsencrypt/live/*/; do
  domain_name=$(basename "$domain")
  chmod 755 "/etc/letsencrypt/live/$domain_name"
  chmod 755 "/etc/letsencrypt/archive/$domain_name"
  chmod 644 "/etc/letsencrypt/live/$domain_name/fullchain.pem"
  chmod 640 "/etc/letsencrypt/live/$domain_name/privkey.pem"
  chgrp postgres "/etc/letsencrypt/live/$domain_name/privkey.pem"
done
systemctl reload postgresql@*-*
EOF
  sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-postgres.sh

  USE_LE_SSL="yes"
}

generate_ssl() {
  echo "🔐 Generating self-signed SSL certificate..."
  sudo mkdir -p "$SSL_DIR"
  CN_VALUE="$HOST1"
  sudo openssl req -new -x509 -days 365 -nodes \
    -out "$SSL_DIR/server.crt" -keyout "$SSL_DIR/server.key" \
    -subj "/CN=$CN_VALUE" >/dev/null 2>&1

  sudo chmod 600 "$SSL_DIR/server.key"
  sudo chown postgres:postgres "$SSL_DIR/server.key" "$SSL_DIR/server.crt"

  sudo sed -i "s|^#*ssl = .*|ssl = on|" "$PG_CONF"
  sudo sed -i "s|^#*ssl_cert_file.*|ssl_cert_file = '$SSL_DIR/server.crt'|" "$PG_CONF"
  sudo sed -i "s|^#*ssl_key_file.*|ssl_key_file = '$SSL_DIR/server.key'|" "$PG_CONF"
  
  # Enable external connections
  sudo sed -i "s|^#*listen_addresses.*|listen_addresses = '*'|" "$PG_CONF"

  # Restart PostgreSQL service
  sudo systemctl restart "$PG_SERVICE"
  sleep 2
  
  # Check if PostgreSQL started successfully
  if ! sudo systemctl is-active --quiet "$PG_SERVICE"; then
    echo "❌ PostgreSQL failed to start with self-signed SSL. Check logs:"
    sudo journalctl -u "$PG_SERVICE" -n 5 --no-pager
    return 1
  fi
  
  SSL_TYPE="Self-signed"
}

create_user_db() {
  echo "👤 Creating user and database..."
  
  # Ensure PostgreSQL is running before attempting database operations
  if ! sudo systemctl is-active --quiet "$PG_SERVICE"; then
    echo "⚠️ PostgreSQL is not running. Attempting to start..."
    sudo systemctl start "$PG_SERVICE"
    sleep 3
    
    if ! sudo systemctl is-active --quiet "$PG_SERVICE"; then
      echo "❌ Failed to start PostgreSQL. Check the service status:"
      sudo systemctl status "$PG_SERVICE" --no-pager -l
      exit 1
    fi
    echo "✅ PostgreSQL started successfully"
  fi
  
  # Create user if it doesn't exist
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DBUSER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DBUSER WITH PASSWORD '$DBPASS';"

  # Create database if it doesn't exist
  sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DBNAME" || \
    sudo -u postgres createdb "$DBNAME" -O "$DBUSER"
}

save_credentials() {
  echo
  echo "💾 Saving credentials into ~/.db_cred ..."
  cat > "$HOME/.db_cred" <<CREDFILE
DBUSER=$DBUSER
DBPASS=$DBPASS
DBNAME=$DBNAME
PRIVATE_IP=$PRIVATE_IP
PUBLIC_IP4=$PUBLIC_IP4
PUBLIC_IP6=$PUBLIC_IP6
HOST1=$HOST1
HOST2=$HOST2
PUBLIC=$PUBLIC
CREDFILE
  chmod 600 "$HOME/.db_cred"
  echo "✅ Credentials saved at $HOME/.db_cred"
}

print_info() {
  echo
  echo "✅ Setup Complete!"
  echo "DB:   $DBNAME"
  echo "User: $DBUSER"
  echo "Pass: $DBPASS"
  echo "SSL:  $SSL_TYPE"

  echo
  echo "📌 Connection Strings:"
  echo "1) Private IP:   postgres://$DBUSER:$DBPASS@$PRIVATE_IP:5432/$DBNAME?sslmode=require"
  [[ -n "$PUBLIC_IP4" ]] && echo "2) Public IPv4:  postgres://$DBUSER:$DBPASS@$PUBLIC_IP4:5432/$DBNAME?sslmode=require"
  [[ -n "$PUBLIC_IP6" ]] && echo "3) Public IPv6:  postgres://$DBUSER:$DBPASS@[$PUBLIC_IP6]:5432/$DBNAME?sslmode=require"
  [[ -n "$HOST1" ]] && echo "4) Hostname 1:   postgres://$DBUSER:$DBPASS@$HOST1:5432/$DBNAME?sslmode=require"
  [[ -n "$HOST2" ]] && echo "5) Hostname 2:   postgres://$DBUSER:$DBPASS@$HOST2:5432/$DBNAME?sslmode=require"
}

check_port() {
  echo
  echo "🔍 Checking PostgreSQL port (5432)..."
  for TARGET in "127.0.0.1" "$PRIVATE_IP" "$PUBLIC_IP4" "$PUBLIC_IP6" "$HOST1" "$HOST2"; do
    [[ -z "$TARGET" ]] && continue
    echo -n "Port check on $TARGET ... "
    if timeout 3 bash -c "</dev/tcp/$TARGET/5432" >/dev/null 2>&1; then
      echo "✅ Open"
    else
      echo "❌ Closed/Blocked"
    fi
  done
}

test_all_connectivity() {
  echo
  echo "🔍 Testing PostgreSQL connectivity..."
  for TARGET in "127.0.0.1" "$PRIVATE_IP" "$PUBLIC_IP4" "$PUBLIC_IP6" "$HOST1" "$HOST2"; do
    [[ -z "$TARGET" ]] && continue
    echo -n "Testing DB connection to $TARGET ... "
    if timeout 10 bash -c "PGPASSWORD='$DBPASS' psql -h '$TARGET' -U '$DBUSER' -d '$DBNAME' -c '\q' >/dev/null 2>&1"; then
      echo "✅ OK"
    else
      echo "❌ FAILED"
    fi
  done
}

# ============================================================
# Main Flow
# ============================================================

main() {
  echo "🚀 Starting PostgreSQL Setup with SSL..."
  
  # Check if PostgreSQL is installed
  if ! command -v psql >/dev/null 2>&1; then
    echo "❌ PostgreSQL is not installed. Please install PostgreSQL first."
    echo "   Run: sudo apt update && sudo apt install -y postgresql postgresql-contrib"
    exit 1
  fi
  
  # Check if PostgreSQL cluster exists and get the correct service name
  CLUSTER_INFO=$(sudo pg_lsclusters | grep -v "^Ver" | head -n1)
  if [[ -z "$CLUSTER_INFO" ]]; then
    echo "❌ No PostgreSQL clusters found. Please check your PostgreSQL installation."
    exit 1
  fi
  
  # Extract version and cluster name from pg_lsclusters output
  PG_VERSION=$(echo "$CLUSTER_INFO" | awk '{print $1}')
  PG_CLUSTER=$(echo "$CLUSTER_INFO" | awk '{print $2}')
  PG_SERVICE="postgresql@${PG_VERSION}-${PG_CLUSTER}"
  
  echo "📋 Found PostgreSQL cluster: $PG_VERSION/$PG_CLUSTER (service: $PG_SERVICE)"
  
  # Update global variables to use the detected version
  PG_HBA="/etc/postgresql/${PG_VERSION}/${PG_CLUSTER}/pg_hba.conf"
  PG_CONF="/etc/postgresql/${PG_VERSION}/${PG_CLUSTER}/postgresql.conf"

  load_saved_credentials

  if [[ "$USE_SAVED" != "yes" ]]; then
    collect_inputs
  fi

  verify_hostname_mapping
  update_pg_hba
  
  # Try Let's Encrypt SSL first, fallback to self-signed if it fails
  if ! setup_domain_ssl; then
    echo "⚠️ Let's Encrypt SSL failed, falling back to self-signed certificate..."
    generate_ssl
  fi
  
  create_user_db
  save_credentials
  print_info
  check_port
  test_all_connectivity
  
  echo "🎉 PostgreSQL setup completed successfully!"
}

main "$@"
