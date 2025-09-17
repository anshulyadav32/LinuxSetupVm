#!/bin/bash

# Ensure you're running this as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root!"
  exit 1
fi

# Define the default password
DEFAULT_PASSWORD="AYss8958"
SSH_CONFIG="/etc/ssh/sshd_config"

# Function to check if SSH is installed
check_ssh_installed() {
  if ! command -v sshd &> /dev/null; then
    echo "SSH is not installed. Installing SSH..."
    apt update && apt install -y openssh-server
  else
    echo "SSH is already installed."
  fi
}

# Function to check if SSH service is running
check_ssh_service() {
  if systemctl is-active --quiet ssh; then
    echo "SSH service is running."
  else
    echo "SSH service is not running. Starting SSH..."
    systemctl start ssh
  fi
}

# Function to check if root login is enabled in sshd_config
check_root_login_enabled() {
  if grep -q "^PermitRootLogin yes" $SSH_CONFIG; then
    echo "Root login is already enabled in SSH config."
  else
    echo "Enabling root login in SSH config..."
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' $SSH_CONFIG
    echo "Root login has been enabled."
  fi
}

# Function to set the root password
set_root_password() {
  echo "Setting root password..."
  echo "root:$DEFAULT_PASSWORD" | chpasswd
  echo "Root password has been set to the default."
}

# Function to restart SSH service
restart_ssh_service() {
  echo "Restarting SSH service..."
  systemctl restart ssh
}

# Function to test SSH connection locally
# Requires sshpass to be installed
# Usage: apt-get install sshpass

test_ssh_connection() {
  echo "Testing SSH connection..."
  sshpass -p "$DEFAULT_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@localhost "echo SSH connection successful"
  if [ $? -eq 0 ]; then
    echo "SSH test connection successful!"
  else
    echo "SSH test connection failed. Please check SSH configuration and firewall settings."
  fi
}

# Execute functions
check_ssh_installed
check_ssh_service
check_root_login_enabled
set_root_password
restart_ssh_service
test_ssh_connection

echo "SSH root access setup and test complete."
