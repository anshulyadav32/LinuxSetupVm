# Linux Server Setup

To update your Linux server, use the following command:

```bash
sudo apt update && sudo apt upgrade -y
```

## Install and Update Functions

Scripts for installing and updating PostgreSQL and dependencies:

**Install:**
```bash
sudo bash function/install.sh
```

**Update:**
```bash
sudo bash function/update.sh
```

## Full PostgreSQL Setup Script

The complete PostgreSQL setup script is available in the `fs` folder:

```bash
sudo bash fs/PostgreServerSetup.sh
```

Or run directly from GitHub:
```bash
curl -sSL https://raw.githubusercontent.com/anshulyadax/LinuxSetupVm/main/PostgreServerSetup.sh | bash
```

## Setup Domain with Nginx and SSL

To set up a domain with Nginx and SSL, use:
```bash
sudo bash setupDomainNphpServerWithSSL.sh
```

This script will:
- Install Nginx and Certbot
- Configure your domain
- Set up SSL with Let's Encrypt
- Enable auto-renewal
- Check domain readiness

## Quick PostgreSQL Smart Setup

Run this command to automatically download and execute the PostgreSQL setup script:

```bash
curl -sSL https://raw.githubusercontent.com/anshulyadax/LinuxSetupVm/main/PostgreServerSetup.sh | bash
```