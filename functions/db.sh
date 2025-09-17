#!/bin/bash

check_postgresql_installed() {
  if ! command -v psql >/dev/null 2>&1; then
    echo "❌ PostgreSQL is not installed. Please install PostgreSQL first."
    echo "   Run: sudo apt update && sudo apt install -y postgresql postgresql-contrib"
    exit 1
  fi
}

check_postgresql_cluster() {
  CLUSTER_INFO=$(sudo pg_lsclusters | grep -v "^Ver" | head -n1)
  if [[ -z "$CLUSTER_INFO" ]]; then
    echo "❌ No PostgreSQL clusters found. Please check your PostgreSQL installation."
    exit 1
  fi

  PG_VERSION=$(echo "$CLUSTER_INFO" | awk '{print $1}')
  PG_CLUSTER=$(echo "$CLUSTER_INFO" | awk '{print $2}')
  PG_SERVICE="postgresql@${PG_VERSION}-${PG_CLUSTER}"

  echo "📋 Found PostgreSQL cluster: $PG_VERSION/$PG_CLUSTER (service: $PG_SERVICE)"
}

create_user_db() {
  echo "👤 Creating user and database..."
  check_postgresql_status
  create_pg_user
  create_pg_db
}

check_postgresql_status() {
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
}

create_pg_user() {
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DBUSER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DBUSER WITH PASSWORD '$DBPASS';"
}

create_pg_db() {
  sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DBNAME" || \
    sudo -u postgres createdb "$DBNAME" -O "$DBUSER"
}

save_credentials() {
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
