#!/bin/bash
# Function to create a PostgreSQL user and database
# Usage: create_psql_user_db <username> <password> <dbname>

create_psql_user_db() {
  local DBUSER="$1"
  local DBPASS="$2"
  local DBNAME="$3"

  if [[ -z "$DBUSER" || -z "$DBPASS" || -z "$DBNAME" ]]; then
    echo "Usage: create_psql_user_db <username> <password> <dbname>"
    return 1
  fi

  # Create user if it doesn't exist
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DBUSER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DBUSER WITH PASSWORD '$DBPASS';"

  # Create database if it doesn't exist
  sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DBNAME" || \
    sudo -u postgres createdb "$DBNAME" -O "$DBUSER"

  echo "✅ PostgreSQL user '$DBUSER' and database '$DBNAME' created."
}
