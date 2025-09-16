# Linux Server Setup

To update your Linux server, use the following command:

```bash
sudo apt update && sudo apt upgrade -y
```

## Quick PostgreSQL Smart Setup

Run this command to automatically download and execute the PostgreSQL setup script:

```bash
curl -sSL https://raw.githubusercontent.com/anshulyadax/LinuxSetupVm/main/PostgreServerSetup.sh | bash
```