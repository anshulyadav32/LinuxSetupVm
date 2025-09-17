#!/bin/bash

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
    echo "hostssl all all 0.0.0.0/0 md5" | sudo tee -a "$PG_HBA"
    echo "hostssl all all ::/0 md5" | sudo tee -a "$PG_HBA"
  fi

  echo "hostssl all all ::1/128 md5" | sudo tee -a "$PG_HBA"
}
