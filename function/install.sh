#!/bin/bash
# Install script for PostgreSQL and dependencies

echo "Running install script..."

# Update package list and install PostgreSQL, Certbot, and OpenSSL
echo "Installing PostgreSQL and dependencies..."
sudo apt update && sudo apt install -y postgresql certbot openssl

echo "Installation complete."