#!/bin/bash
# Function: Update PostgreSQL and system packages

echo "Updating PostgreSQL and system packages..."
sudo apt update && sudo apt upgrade -y
sudo systemctl restart postgresql