#!/bin/bash

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

collect_inputs_if_needed() {
  if [[ "$USE_SAVED" != "yes" ]]; then
    collect_inputs
  fi
}

collect_inputs() {
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
