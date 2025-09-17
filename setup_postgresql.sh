#!/bin/bash
# ============================================================
# PostgreSQL Setup with SSL (Let's Encrypt + Fallback) + User/DB
# Author: Anshul Yadav
# ============================================================

set -e

# Import functions
source ./functions/common.sh
source ./functions/ssl.sh
source ./functions/db.sh
source ./functions/hostname.sh

# ===== Auto-detect values =====
DEFAULT_PRIVATE_IP=$(hostname -I | awk '{print $1}')
DEFAULT_PUBLIC_IP4=$(curl -s -4 ifconfig.me || echo "")
DEFAULT_PUBLIC_IP6=$(curl -s -6 ifconfig.me || echo "")
DEFAULT_HOSTNAME=$(hostname -f 2>/dev/null || hostname)

PG_HBA=""
PG_CONF=""
SSL_DIR="/etc/ssl/postgresql"

main() {
  echo "🚀 Starting PostgreSQL Setup with SSL..."

  check_postgresql_installed
  check_postgresql_cluster
  load_saved_credentials
  collect_inputs_if_needed

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
