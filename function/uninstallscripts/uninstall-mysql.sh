#!/bin/bash

# =============================================================================
# Script de Desinstalación MySQL - Linux Setup VM
# =============================================================================
# Descripción: Desinstala completamente MySQL y todas sus versiones
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/linux-setup-vm/uninstall-mysql-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/mysql-backup-$(date +%Y%m%d_%H%M%S)"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
}

print_header() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${YELLOW}                    DESINSTALACIÓN MYSQL${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Detectar versiones de MySQL
detect_mysql_versions() {
    local versions=()
    
    # MySQL principal
    if command -v mysql &>/dev/null; then
        local version=$(mysql --version 2>/dev/null | grep -o 'Ver [0-9.]*' | cut -d' ' -f2)
        versions+=("mysql:$version")
    fi
    
    # Versiones específicas
    for version in 5.7 8.0 8.1 8.2; do
        if command -v "mysql-$version" &>/dev/null; then
            versions+=("mysql-$version")
        fi
    done
    
    printf '%s\n' "${versions[@]}"
}

# Detectar paquetes MySQL
detect_mysql_packages() {
    local packages=()
    
    # Paquetes principales
    for pkg in mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=($(dpkg -l | grep "^ii.*$pkg" | awk '{print $2}'))
        fi
    done
    
    # Librerías MySQL
    for pkg in libmysqlclient* mysql-apt-config; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=($(dpkg -l | grep "^ii.*$pkg" | awk '{print $2}'))
        fi
    done
    
    printf '%s\n' "${packages[@]}"
}

# Detectar servicios MySQL
detect_mysql_services() {
    local services=()
    
    for service in mysql mysqld mysql.service; do
        if systemctl list-units --type=service | grep -q "$service"; then
            services+=("$service")
        fi
    done
    
    printf '%s\n' "${services[@]}"
}

# Crear backup de bases de datos
backup_databases() {
    log_message "INFO" "Creando respaldo de bases de datos en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Verificar si MySQL está ejecutándose
    if ! systemctl is-active mysql &>/dev/null && ! systemctl is-active mysqld &>/dev/null; then
        log_message "WARN" "MySQL no está ejecutándose, intentando iniciar para backup..."
        sudo systemctl start mysql 2>/dev/null || sudo systemctl start mysqld 2>/dev/null || true
        sleep 3
    fi
    
    # Intentar backup si MySQL está disponible
    if command -v mysqldump &>/dev/null && mysql -e "SELECT 1" &>/dev/null; then
        log_message "INFO" "Creando respaldo de todas las bases de datos..."
        
        # Backup de todas las bases de datos
        mysqldump --all-databases --routines --triggers --events > "$BACKUP_DIR/all-databases.sql" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log_message "INFO" "✅ Respaldo de bases de datos completado"
        else
            log_message "WARN" "⚠️  No se pudo crear respaldo automático de bases de datos"
        fi
        
        # Lista de bases de datos
        mysql -e "SHOW DATABASES;" > "$BACKUP_DIR/databases-list.txt" 2>/dev/null
        
        # Información de usuarios
        mysql -e "SELECT User, Host FROM mysql.user;" > "$BACKUP_DIR/mysql-users.txt" 2>/dev/null
        
    else
        log_message "WARN" "No se puede acceder a MySQL para crear respaldo"
    fi
    
    # Backup de configuraciones
    if [ -f "/etc/mysql/my.cnf" ]; then
        cp "/etc/mysql/my.cnf" "$BACKUP_DIR/my.cnf" 2>/dev/null
        log_message "INFO" "✅ Respaldo de configuración my.cnf"
    fi
    
    # Backup de directorio de configuración completo
    if [ -d "/etc/mysql" ]; then
        cp -r "/etc/mysql" "$BACKUP_DIR/mysql-config" 2>/dev/null
        log_message "INFO" "✅ Respaldo de configuraciones /etc/mysql"
    fi
    
    # Backup de logs
    if [ -d "/var/log/mysql" ]; then
        cp -r "/var/log/mysql" "$BACKUP_DIR/mysql-logs" 2>/dev/null
        log_message "INFO" "✅ Respaldo de logs /var/log/mysql"
    fi
    
    # Información del servicio
    systemctl status mysql > "$BACKUP_DIR/mysql-service-status.txt" 2>/dev/null || \
    systemctl status mysqld > "$BACKUP_DIR/mysql-service-status.txt" 2>/dev/null
    
    # Lista de paquetes instalados
    dpkg -l | grep mysql > "$BACKUP_DIR/mysql-packages.txt" 2>/dev/null
    
    # Comprimir respaldo
    tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null
    rm -rf "$BACKUP_DIR"
    
    log_message "INFO" "✅ Respaldo comprimido guardado en: $BACKUP_DIR.tar.gz"
}

# Detener servicios MySQL
stop_mysql_services() {
    local services=($(detect_mysql_services))
    
    if [ ${#services[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron servicios MySQL ejecutándose"
        return 0
    fi
    
    log_message "INFO" "Deteniendo servicios MySQL..."
    
    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log_message "INFO" "Deteniendo servicio: $service"
            sudo systemctl stop "$service" 2>&1 | tee -a "$LOG_FILE"
            sudo systemctl disable "$service" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
    
    # Verificar que los procesos se hayan detenido
    if pgrep mysqld &>/dev/null; then
        log_message "WARN" "Forzando terminación de procesos MySQL restantes"
        sudo pkill -f mysqld 2>/dev/null || true
        sleep 2
        sudo pkill -9 -f mysqld 2>/dev/null || true
    fi
}

# Eliminar paquetes MySQL
remove_mysql_packages() {
    local packages=($(detect_mysql_packages))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron paquetes MySQL para eliminar"
        return 0
    fi
    
    log_message "INFO" "Eliminando paquetes MySQL del sistema..."
    
    echo -e "${YELLOW}Paquetes que serán eliminados:${NC}"
    for pkg in "${packages[@]}"; do
        echo -e "${RED}  - $pkg${NC}"
    done
    
    # Eliminar paquetes
    sudo apt-get remove --purge -y "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Autoremove
    sudo apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
}

# Eliminar directorios y archivos MySQL
remove_mysql_files() {
    log_message "INFO" "Eliminando directorios y archivos MySQL..."
    
    # Directorios principales
    local mysql_dirs=(
        "/etc/mysql"
        "/var/lib/mysql"
        "/var/log/mysql"
        "/var/cache/mysql"
        "/usr/share/mysql"
        "/etc/init.d/mysql"
        "/etc/logrotate.d/mysql-server"
        "/lib/systemd/system/mysql.service"
        "/lib/systemd/system/mysqld.service"
        "/etc/systemd/system/mysql.service"
        "/etc/systemd/system/mysqld.service"
        "/etc/apparmor.d/usr.sbin.mysqld"
    )
    
    for dir in "${mysql_dirs[@]}"; do
        if [ -e "$dir" ]; then
            log_message "INFO" "Eliminando: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    # Usuario mysql
    if id "mysql" &>/dev/null; then
        log_message "INFO" "Eliminando usuario mysql"
        sudo userdel mysql 2>/dev/null || true
    fi
    
    # Grupo mysql
    if getent group mysql &>/dev/null; then
        log_message "INFO" "Eliminando grupo mysql"
        sudo groupdel mysql 2>/dev/null || true
    fi
    
    # Archivos de configuración residuales
    find /etc -name "*mysql*" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            log_message "INFO" "Eliminando archivo residual: $file"
            sudo rm -f "$file"
        fi
    done
    
    # Limpiar systemd
    sudo systemctl daemon-reload 2>&1 | tee -a "$LOG_FILE"
    
    # Limpiar AppArmor profiles
    if [ -d "/etc/apparmor.d" ]; then
        find /etc/apparmor.d -name "*mysql*" -type f | while read -r file; do
            log_message "INFO" "Eliminando perfil AppArmor: $file"
            sudo rm -f "$file"
        done
        sudo apparmor_parser -R /etc/apparmor.d/* 2>/dev/null || true
    fi
}

# Limpiar repositorios MySQL
clean_repositories() {
    log_message "INFO" "Limpiando repositorios MySQL..."
    
    # Eliminar claves GPG de MySQL
    local keys=(
        "mysql"
        "5072E1F5"
        "8C718D3B5072E1F5"
        "B7B3B788A8D3785C"
    )
    
    for key in "${keys[@]}"; do
        if apt-key list 2>/dev/null | grep -i "$key"; then
            log_message "INFO" "Eliminando clave GPG: $key"
            sudo apt-key del "$key" 2>/dev/null || true
        fi
    done
    
    # Eliminar archivos de repositorio
    local repo_files=(
        "/etc/apt/sources.list.d/mysql.list"
        "/etc/apt/sources.list.d/mysql-apt-config.list"
        "/etc/apt/keyrings/mysql-archive-keyring.gpg"
    )
    
    for file in "${repo_files[@]}"; do
        if [ -f "$file" ]; then
            log_message "INFO" "Eliminando archivo de repositorio: $file"
            sudo rm -f "$file"
        fi
    done
    
    # Actualizar cache de paquetes
    sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
}

# Limpiar firewall
clean_firewall_rules() {
    log_message "INFO" "Limpiando reglas de firewall para MySQL..."
    
    # UFW rules
    if command -v ufw &>/dev/null; then
        # Eliminar reglas comunes de MySQL
        for rule in "3306" "3306/tcp" "mysql"; do
            if ufw status | grep -q "$rule"; then
                log_message "INFO" "Eliminando regla UFW: $rule"
                sudo ufw delete allow "$rule" 2>/dev/null || true
            fi
        done
    fi
}

# Verificar desinstalación
verify_removal() {
    log_message "INFO" "Verificando desinstalación..."
    
    local issues=0
    
    # Verificar comandos MySQL
    for cmd in mysql mysqld mysqldump; do
        if command -v "$cmd" &>/dev/null; then
            log_message "WARN" "⚠️  Comando aún disponible: $cmd"
            ((issues++))
        fi
    done
    
    # Verificar servicios
    for service in mysql mysqld; do
        if systemctl list-units --type=service | grep -q "$service"; then
            log_message "WARN" "⚠️  Servicio aún presente: $service"
            ((issues++))
        fi
    done
    
    # Verificar procesos
    if pgrep mysqld &>/dev/null; then
        log_message "WARN" "⚠️  Procesos MySQL aún ejecutándose"
        ((issues++))
    fi
    
    # Verificar directorios principales
    for dir in "/etc/mysql" "/var/lib/mysql" "/var/log/mysql"; do
        if [ -d "$dir" ]; then
            log_message "WARN" "⚠️  Directorio aún existe: $dir"
            ((issues++))
        fi
    done
    
    # Verificar paquetes
    local remaining_packages=($(detect_mysql_packages))
    if [ ${#remaining_packages[@]} -gt 0 ]; then
        log_message "WARN" "⚠️  Paquetes aún instalados: ${remaining_packages[*]}"
        ((issues++))
    fi
    
    # Verificar puerto 3306
    if netstat -tlnp 2>/dev/null | grep ":3306"; then
        log_message "WARN" "⚠️  Puerto 3306 aún en uso"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        log_message "INFO" "✅ Desinstalación completada exitosamente"
        return 0
    else
        log_message "WARN" "⚠️  Desinstalación completada con $issues advertencias"
        return 1
    fi
}

# Función principal
main() {
    print_header
    
    # Verificar si MySQL está instalado
    if ! command -v mysql &>/dev/null && [ ${#$(detect_mysql_packages)} -eq 0 ]; then
        log_message "INFO" "MySQL no está instalado en el sistema"
        exit 0
    fi
    
    log_message "INFO" "Iniciando desinstalación de MySQL..."
    
    # Mostrar componentes detectados
    echo -e "${YELLOW}Componentes MySQL detectados:${NC}"
    
    local versions=($(detect_mysql_versions))
    if [ ${#versions[@]} -gt 0 ]; then
        echo -e "${BLUE}Versiones: ${versions[*]}${NC}"
    fi
    
    local packages=($(detect_mysql_packages))
    if [ ${#packages[@]} -gt 0 ]; then
        echo -e "${BLUE}Paquetes del sistema: ${#packages[@]} paquetes${NC}"
    fi
    
    local services=($(detect_mysql_services))
    if [ ${#services[@]} -gt 0 ]; then
        echo -e "${BLUE}Servicios: ${services[*]}${NC}"
    fi
    
    # Mostrar bases de datos si es posible
    if command -v mysql &>/dev/null && mysql -e "SELECT 1" &>/dev/null 2>&1; then
        local db_count=$(mysql -e "SHOW DATABASES;" 2>/dev/null | wc -l)
        echo -e "${BLUE}Bases de datos: $((db_count - 1))${NC}"
    fi
    
    echo
    echo -e "${RED}⚠️  ADVERTENCIA: Esta operación eliminará TODAS las bases de datos MySQL${NC}"
    echo -e "${YELLOW}Se creará un respaldo automático antes de la desinstalación${NC}"
    echo
    
    # Confirmación
    echo -e "${YELLOW}¿Desea continuar con la desinstalación completa de MySQL? (s/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log_message "INFO" "Desinstalación cancelada por el usuario"
        exit 0
    fi
    
    # Proceso de desinstalación
    backup_databases
    stop_mysql_services
    remove_mysql_packages
    remove_mysql_files
    clean_repositories
    clean_firewall_rules
    verify_removal
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}✅ Desinstalación de MySQL completada${NC}"
    echo -e "${GREEN}📄 Log guardado en: $LOG_FILE${NC}"
    if [ -f "$BACKUP_DIR.tar.gz" ]; then
        echo -e "${GREEN}💾 Respaldo guardado en: $BACKUP_DIR.tar.gz${NC}"
    fi
    echo -e "${YELLOW}⚠️  Importante: Restaure las bases de datos desde el respaldo si es necesario${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
}

# Ejecutar función principal
main "$@"