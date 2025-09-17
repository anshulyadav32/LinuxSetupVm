# 🚀 Linux Setup VM - Complete System Management Suite

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub Pages](https://img.shields.io/badge/GitHub-Pages-blue.svg)](https://pages.github.com/)

A comprehensive collection of automated scripts for installing, updating, uninstalling, and monitoring software components on Linux systems. Perfect for developers, system administrators, and DevOps engineers who need reliable automation tools.

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Usage](#-usage)
- [Components](#-components)
- [Scripts Overview](#-scripts-overview)
- [Examples](#-examples)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

### 🔧 **Installation Scripts**
- **Automated installation** of popular development tools
- **Dependency management** and conflict resolution
- **Configuration optimization** for each component
- **Post-installation verification** and testing

### 🗑️ **Uninstallation Scripts**
- **Complete removal** of software and configurations
- **Automatic backup** before uninstallation
- **Cleanup of residual files** and directories
- **Repository and key management**

### 🔄 **Update Scripts**
- **Intelligent version detection** and updates
- **Rollback capability** in case of failures
- **Batch updates** for multiple components
- **Changelog and version tracking**

### 🔍 **Health Monitoring**
- **Real-time system monitoring** (CPU, RAM, Disk, Network)
- **Component health checks** with intelligent alerts
- **Performance optimization** recommendations
- **JSON output** for integration with monitoring systems

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/LinuxSetupVm.git
cd LinuxSetupVm

# Make scripts executable
chmod +x function/install.sh
chmod +x function/update.sh

# Install a component (e.g., Docker)
./function/install.sh docker

# Check system health
./function/checker/health-checker.sh --summary

# Update all components
./function/update.sh --all
```

## 📦 Installation

### Prerequisites
- Linux-based operating system (Ubuntu, Debian, CentOS, etc.)
- Bash shell (version 4.0 or higher)
- Root or sudo privileges
- Internet connection for downloading packages

### Setup
1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/LinuxSetupVm.git
   cd LinuxSetupVm
   ```

2. **Set permissions:**
   ```bash
   find function/ -name "*.sh" -exec chmod +x {} \;
   ```

3. **Verify installation:**
   ```bash
   ./function/checker/health-checker.sh --help
   ```

## 🎯 Usage

### Installation
```bash
# Interactive installation menu
./function/install.sh

# Install specific component
./function/install.sh docker

# Install multiple components
./function/install.sh docker nodejs nginx
```

### Health Monitoring
```bash
# Complete system health check
./function/checker/health-checker.sh --all

# Monitor specific components
./function/checker/health-checker.sh docker nginx mysql

# Continuous monitoring
./function/checker/system-monitor.sh --continuous --interval 10

# JSON output for automation
./function/checker/health-checker.sh --json --all
```

### Uninstallation
```bash
# Interactive uninstallation
./function/uninstallscripts/uninstall-master.sh

# Preview what will be removed
./function/uninstallscripts/uninstall-docker.sh --preview

# Execute uninstallation
./function/uninstallscripts/uninstall-docker.sh --execute
```

### Updates
```bash
# Update all components
./function/updatescripts/update-master.sh --all

# Update specific component
./function/updatescripts/update-master.sh docker

# Check for available updates
./function/updatescripts/update-master.sh --check-only
```

## 🧩 Components

### **Development Tools**
| Component | Description | Installation Script | Uninstall Script |
|-----------|-------------|-------------------|------------------|
| **Docker** | Container platform | `docker.sh` | `uninstall-docker.sh` |
| **Node.js** | JavaScript runtime | `nodejs.sh` | `uninstall-nodejs.sh` |
| **Python** | Programming language | `python.sh` | ✅ Supported |
| **Git** | Version control | `git.sh` | ✅ Supported |
| **PM2** | Process manager | `pm2.sh` | ✅ Supported |

### **Web Servers**
| Component | Description | Installation Script | Uninstall Script |
|-----------|-------------|-------------------|------------------|
| **Nginx** | Web server | `nginx.sh` | `uninstall-nginx.sh` |
| **Apache** | Web server | `apache.sh` | ✅ Supported |
| **PHP** | Server-side language | `php.sh` | ✅ Supported |

### **Databases**
| Component | Description | Installation Script | Uninstall Script |
|-----------|-------------|-------------------|------------------|
| **MySQL** | Relational database | `mysql.sh` | `uninstall-mysql.sh` |
| **PostgreSQL** | Advanced database | `postgresql.sh` | `uninstall-postgresql.sh` |
| **Redis** | In-memory database | `redis.sh` | ✅ Supported |
| **MongoDB** | NoSQL database | `mongodb.sh` | ✅ Supported |

### **Security & Utilities**
| Component | Description | Installation Script | Uninstall Script |
|-----------|-------------|-------------------|------------------|
| **UFW Firewall** | Firewall management | `ufw-firewall.sh` | ✅ Supported |
| **SSL Certbot** | SSL certificates | `ssl-certbot.sh` | ✅ Supported |
| **System Utilities** | Essential tools | `system-utilities.sh` | ✅ Supported |

## 📁 Scripts Overview

### **Directory Structure**
```
LinuxSetupVm/
├── function/
│   ├── install.sh              # Main installation script
│   ├── update.sh               # Main update script
│   ├── installscripts/         # Individual installation scripts
│   │   ├── docker.sh
│   │   ├── nodejs.sh
│   │   ├── nginx.sh
│   │   └── ...
│   ├── uninstallscripts/       # Uninstallation scripts
│   │   ├── uninstall-master.sh
│   │   ├── uninstall-docker.sh
│   │   └── ...
│   ├── updatescripts/          # Update scripts
│   │   └── update-master.sh
│   └── checker/                # Monitoring and health scripts
│       ├── health-checker.sh
│       ├── component-status.sh
│       └── system-monitor.sh
├── website/                    # GitHub Pages website
│   ├── index.html
│   ├── css/
│   └── js/
└── README.md
```

### **Key Features of Each Script Type**

#### 🔧 **Installation Scripts**
- **Dependency checking** and automatic resolution
- **Version compatibility** verification
- **Configuration optimization** for production use
- **Service setup** and automatic startup configuration
- **Security hardening** with best practices
- **Post-installation testing** and verification

#### 🗑️ **Uninstallation Scripts**
- **Intelligent detection** of installed components
- **Complete removal** including configuration files
- **Automatic backup** creation before removal
- **Service cleanup** and process termination
- **Repository and GPG key cleanup**
- **Verification** of successful removal

#### 🔄 **Update Scripts**
- **Version comparison** and update detection
- **Backup creation** before updates
- **Rollback mechanism** for failed updates
- **Service restart** management
- **Configuration preservation**
- **Update verification** and testing

#### 🔍 **Monitoring Scripts**
- **Real-time resource monitoring** (CPU, RAM, Disk, Network)
- **Service health checks** with status reporting
- **Performance metrics** collection and analysis
- **Alert system** with configurable thresholds
- **JSON output** for integration with external systems
- **Historical data** logging and analysis

## 💡 Examples

### **Complete Development Environment Setup**
```bash
# Install full development stack
./function/install.sh docker nodejs nginx mysql redis

# Verify installation
./function/checker/health-checker.sh docker nodejs nginx mysql redis

# Monitor system performance
./function/checker/system-monitor.sh --continuous
```

### **Database Server Setup**
```bash
# Install database components
./function/install.sh mysql postgresql redis

# Check database health
./function/checker/component-status.sh mysql --verbose
./function/checker/component-status.sh postgresql --verbose

# Monitor database performance
./function/checker/health-checker.sh mysql postgresql --detailed
```

### **Web Server Configuration**
```bash
# Install web server stack
./function/install.sh nginx php ssl-certbot ufw-firewall

# Verify SSL configuration
./function/checker/component-status.sh ssl-certbot --verbose

# Monitor web server health
./function/checker/health-checker.sh nginx php --warnings
```

### **System Maintenance**
```bash
# Check system health
./function/checker/health-checker.sh --summary

# Update all components
./function/updatescripts/update-master.sh --all

# Clean up unused components
./function/uninstallscripts/uninstall-master.sh --interactive
```

## 🔧 Advanced Configuration

### **Environment Variables**
```bash
# Set custom log directory
export LINUX_SETUP_LOG_DIR="/var/log/linux-setup-vm"

# Enable debug mode
export LINUX_SETUP_DEBUG=true

# Set custom backup directory
export LINUX_SETUP_BACKUP_DIR="/backup/linux-setup-vm"
```

### **Custom Thresholds**
```bash
# CPU usage warning threshold (default: 70%)
export CPU_WARNING_THRESHOLD=80

# Memory usage critical threshold (default: 85%)
export MEMORY_CRITICAL_THRESHOLD=90

# Disk usage warning threshold (default: 80%)
export DISK_WARNING_THRESHOLD=75
```

## 🚨 Troubleshooting

### **Common Issues**

#### **Permission Denied**
```bash
# Fix script permissions
find function/ -name "*.sh" -exec chmod +x {} \;
```

#### **Missing Dependencies**
```bash
# Install required tools
sudo apt-get update
sudo apt-get install curl wget git bc
```

#### **Service Start Failures**
```bash
# Check service status
./function/checker/component-status.sh [component] --verbose

# View system logs
journalctl -u [service-name] -f
```

### **Log Files**
- **Installation logs:** `/var/log/linux-setup-vm/install-*.log`
- **Uninstallation logs:** `/var/log/linux-setup-vm/uninstall-*.log`
- **Health check logs:** `/var/log/linux-setup-vm/health-check-*.log`
- **System monitor logs:** `/var/log/linux-setup-vm/system-monitor-*.log`

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **How to Contribute**
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### **Development Setup**
```bash
# Clone your fork
git clone https://github.com/yourusername/LinuxSetupVm.git
cd LinuxSetupVm

# Create development branch
git checkout -b feature/new-component

# Test your changes
./function/checker/health-checker.sh --all
```

## 📊 System Requirements

### **Minimum Requirements**
- **OS:** Ubuntu 18.04+, Debian 9+, CentOS 7+
- **RAM:** 1GB available
- **Disk:** 2GB free space
- **Network:** Internet connection for downloads

### **Recommended Requirements**
- **OS:** Ubuntu 20.04+, Debian 11+
- **RAM:** 2GB+ available
- **Disk:** 5GB+ free space
- **CPU:** 2+ cores for optimal performance

## 🔒 Security

### **Security Features**
- **Input validation** and sanitization
- **Privilege escalation** protection
- **Secure download** verification (GPG signatures)
- **Configuration hardening** with security best practices
- **Audit logging** of all operations

### **Security Best Practices**
- Always run scripts with **minimum required privileges**
- **Review scripts** before execution in production
- **Backup critical data** before making changes
- **Monitor logs** for suspicious activity
- **Keep scripts updated** with latest security patches

## 📈 Performance

### **Optimization Features**
- **Parallel processing** for faster installations
- **Caching mechanisms** for repeated operations
- **Resource monitoring** and optimization recommendations
- **Efficient cleanup** routines
- **Minimal system impact** during operations

### **Performance Monitoring**
```bash
# Real-time performance monitoring
./function/checker/system-monitor.sh --continuous --interval 5

# Performance summary
./function/checker/health-checker.sh --summary

# Resource usage by component
./function/checker/health-checker.sh --detailed
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Open Source Community** for inspiration and tools
- **Linux Distribution Maintainers** for package management
- **Contributors** who help improve this project
- **Users** who provide feedback and bug reports

## 📞 Support

### **Getting Help**
- 📖 **Documentation:** Check this README and script help (`--help`)
- 🐛 **Bug Reports:** [GitHub Issues](https://github.com/yourusername/LinuxSetupVm/issues)
- 💡 **Feature Requests:** [GitHub Discussions](https://github.com/yourusername/LinuxSetupVm/discussions)
- 📧 **Contact:** [your-email@example.com](mailto:your-email@example.com)

### **Community**
- 🌟 **Star** this repository if you find it useful
- 🍴 **Fork** and contribute to the project
- 📢 **Share** with others who might benefit
- 💬 **Join** our community discussions

---

<div align="center">

**Made with ❤️ for the Linux community**

[⭐ Star this repo](https://github.com/yourusername/LinuxSetupVm) | [🐛 Report Bug](https://github.com/yourusername/LinuxSetupVm/issues) | [💡 Request Feature](https://github.com/yourusername/LinuxSetupVm/issues)

</div>