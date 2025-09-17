#!/bin/bash

# =============================================================================
# Script de Desinstalación Nginx - Linux Setup VM
# =============================================================================
# Descripción: Desinstala completamente Nginx y todas sus configuraciones
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/linux-setup-vm/uninstall-nginx-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/nginx-backup-$(date +%Y%m%d_%H%M%S)"

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
    echo -e "${YELLOW}                    DESINSTALACIÓN NGINX${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Detectar paquetes Nginx
detect_nginx_packages() {
    local packages=()
    
    # Paquetes principales
    for pkg in nginx nginx-common nginx-core nginx-full nginx-light nginx-extras; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=("$pkg")
        fi
    done
    
    # Módulos adicionales
    for pkg in libnginx-mod-* nginx-module-*; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=($(dpkg -l | grep "^ii.*$pkg" | awk '{print $2}'))
        fi
    done
    
    printf '%s\n' "${packages[@]}"
}

# Detectar servicios Nginx
detect_nginx_services() {
    local services=()
    
    if systemctl list-units --type=service | grep -q nginx; then
        services+=("nginx")
    fi
    
    printf '%s\n' "${services[@]}"
}

# Crear backup de configuraciones
backup_configurations() {
    log_message "INFO" "Creando respaldo de configuraciones en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Configuraciones principales
    if [ -d "/etc/nginx" ]; then
        cp -r "/etc/nginx" "$BACKUP_DIR/nginx-config" 2>/dev/null
        log_message "INFO" "✅ Respaldo de configuraciones /etc/nginx"
    fi
    
    # Logs
    if [ -d "/var/log/nginx" ]; then
        cp -r "/var/log/nginx" "$BACKUP_DIR/nginx-logs" 2>/dev/null
        log_message "INFO" "✅ Respaldo de logs /var/log/nginx"
    fi
    
    # Sitios web
    if [ -d "/var/www" ]; then
        cp -r "/var/www" "$BACKUP_DIR/www-content" 2>/dev/null
        log_message "INFO" "✅ Respaldo de contenido web /var/www"
    fi
    
    # SSL certificates (Let's Encrypt)
    if [ -d "/etc/letsencrypt" ]; then
        cp -r "/etc/letsencrypt" "$BACKUP_DIR/letsencrypt" 2>/dev/null
        log_message "INFO" "✅ Respaldo de certificados SSL"
    fi
    
    # Información del servicio
    if systemctl is-active nginx &>/dev/null; then
        systemctl status nginx > "$BACKUP_DIR/nginx-service-status.txt" 2>/dev/null
    fi
    
    # Lista de paquetes instalados
    dpkg -l | grep nginx > "$BACKUP_DIR/nginx-packages.txt" 2>/dev/null
    
    # Comprimir respaldo
    tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null
    rm -rf "$BACKUP_DIR"
    
    log_message "INFO" "✅ Respaldo comprimido guardado en: $BACKUP_DIR.tar.gz"
}

# Detener servicios Nginx
stop_nginx_services() {
    local services=($(detect_nginx_services))
    
    if [ ${#services[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron servicios Nginx ejecutándose"
        return 0
    fi
    
    log_message "INFO" "Deteniendo servicios Nginx..."
    
    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log_message "INFO" "Deteniendo servicio: $service"
            sudo systemctl stop "$service" 2>&1 | tee -a "$LOG_FILE"
            sudo systemctl disable "$service" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
    
    # Verificar que los procesos se hayan detenido
    if pgrep nginx &>/dev/null; then
        log_message "WARN" "Forzando terminación de procesos Nginx restantes"
        sudo pkill -f nginx 2>/dev/null || true
        sleep 2
        sudo pkill -9 -f nginx 2>/dev/null || true
    fi
}

# Eliminar paquetes Nginx
remove_nginx_packages() {
    local packages=($(detect_nginx_packages))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron paquetes Nginx para eliminar"
        return 0
    fi
    
    log_message "INFO" "Eliminando paquetes Nginx del sistema..."
    
    echo -e "${YELLOW}Paquetes que serán eliminados:${NC}"
    for pkg in "${packages[@]}"; do
        echo -e "${RED}  - $pkg${NC}"
    done
    
    # Eliminar paquetes
    sudo apt-get remove --purge -y "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Autoremove
    sudo apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
}

# Eliminar directorios y archivos Nginx
remove_nginx_files() {
    log_message "INFO" "Eliminando directorios y archivos Nginx..."
    
    # Directorios principales
    local nginx_dirs=(
        "/etc/nginx"
        "/var/log/nginx"
        "/var/cache/nginx"
        "/var/lib/nginx"
        "/usr/share/nginx"
        "/etc/default/nginx"
        "/etc/init.d/nginx"
        "/etc/logrotate.d/nginx"
        "/lib/systemd/system/nginx.service"
        "/etc/systemd/system/nginx.service"
    )
    
    for dir in "${nginx_dirs[@]}"; do
        if [ -e "$dir" ]; then
            log_message "INFO" "Eliminando: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    # Usuario nginx
    if id "nginx" &>/dev/null; then
        log_message "INFO" "Eliminando usuario nginx"
        sudo userdel nginx 2>/dev/null || true
    fi
    
    # Grupo nginx
    if getent group nginx &>/dev/null; then
        log_message "INFO" "Eliminando grupo nginx"
        sudo groupdel nginx 2>/dev/null || true
    fi
    
    # Archivos de configuración residuales
    find /etc -name "*nginx*" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            log_message "INFO" "Eliminando archivo residual: $file"
            sudo rm -f "$file"
        fi
    done
    
    # Limpiar systemd
    sudo systemctl daemon-reload 2>&1 | tee -a "$LOG_FILE"
}

# Limpiar repositorios Nginx
clean_repositories() {
    log_message "INFO" "Limpiando repositorios Nginx..."
    
    # Eliminar claves GPG de Nginx
    local keys=(
        "nginx"
        "573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62"
    )
    
    for key in "${keys[@]}"; do
        if apt-key list 2>/dev/null | grep -i "$key"; then
            log_message "INFO" "Eliminando clave GPG: $key"
            sudo apt-key del "$key" 2>/dev/null || true
        fi
    done
    
    # Eliminar archivos de repositorio
    local repo_files=(
        "/etc/apt/sources.list.d/nginx.list"
        "/etc/apt/sources.list.d/nginx-stable.list"
        "/etc/apt/sources.list.d/nginx-mainline.list"
        "/etc/apt/keyrings/nginx-archive-keyring.gpg"
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
    log_message "INFO" "Limpiando reglas de firewall para Nginx..."
    
    # UFW rules
    if command -v ufw &>/dev/null; then
        # Eliminar reglas comunes de Nginx
        for rule in "Nginx Full" "Nginx HTTP" "Nginx HTTPS" "80" "443" "80/tcp" "443/tcp"; do
            if ufw status | grep -q "$rule"; then
                log_message "INFO" "Eliminando regla UFW: $rule"
                sudo ufw delete allow "$rule" 2>/dev/null || true
            fi
        done
    fi
    
    # iptables rules (básico)
    if command -v iptables &>/dev/null; then
        log_message "INFO" "Nota: Revise manualmente las reglas de iptables para puertos 80 y 443"
    fi
}

# Verificar desinstalación
verify_removal() {
    log_message "INFO" "Verificando desinstalación..."
    
    local issues=0
    
    # Verificar comando nginx
    if command -v nginx &>/dev/null; then
        log_message "WARN" "⚠️  Comando nginx aún disponible"
        ((issues++))
    fi
    
    # Verificar servicios
    if systemctl list-units --type=service | grep -q nginx; then
        log_message "WARN" "⚠️  Servicios nginx aún presentes"
        ((issues++))
    fi
    
    # Verificar procesos
    if pgrep nginx &>/dev/null; then
        log_message "WARN" "⚠️  Procesos nginx aún ejecutándose"
        ((issues++))
    fi
    
    # Verificar directorios principales
    for dir in "/etc/nginx" "/var/log/nginx"; do
        if [ -d "$dir" ]; then
            log_message "WARN" "⚠️  Directorio aún existe: $dir"
            ((issues++))
        fi
    done
    
    # Verificar paquetes
    local remaining_packages=($(detect_nginx_packages))
    if [ ${#remaining_packages[@]} -gt 0 ]; then
        log_message "WARN" "⚠️  Paquetes aún instalados: ${remaining_packages[*]}"
        ((issues++))
    fi
    
    # Verificar puertos
    if netstat -tlnp 2>/dev/null | grep -E ":80|:443" | grep -v "127.0.0.1"; then
        log_message "WARN" "⚠️  Puertos 80/443 aún en uso (puede ser otro servicio)"
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
    
    # Verificar si Nginx está instalado
    if ! command -v nginx &>/dev/null && [ ${#$(detect_nginx_packages)} -eq 0 ]; then
        log_message "INFO" "Nginx no está instalado en el sistema"
        exit 0
    fi
    
    log_message "INFO" "Iniciando desinstalación de Nginx..."
    
    # Mostrar componentes detectados
    echo -e "${YELLOW}Componentes Nginx detectados:${NC}"
    
    if command -v nginx &>/dev/null; then
        local version=$(nginx -v 2>&1 | grep -o 'nginx/[0-9.]*')
        echo -e "${BLUE}Versión: $version${NC}"
    fi
    
    local packages=($(detect_nginx_packages))
    if [ ${#packages[@]} -gt 0 ]; then
        echo -e "${BLUE}Paquetes del sistema: ${#packages[@]} paquetes${NC}"
    fi
    
    local services=($(detect_nginx_services))
    if [ ${#services[@]} -gt 0 ]; then
        echo -e "${BLUE}Servicios: ${services[*]}${NC}"
    fi
    
    if [ -d "/etc/nginx" ]; then
        local sites=$(find /etc/nginx/sites-enabled -type l 2>/dev/null | wc -l)
        echo -e "${BLUE}Sitios configurados: $sites${NC}"
    fi
    
    echo
    
    # Confirmación
    echo -e "${YELLOW}¿Desea continuar con la desinstalación completa de Nginx? (s/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log_message "INFO" "Desinstalación cancelada por el usuario"
        exit 0
    fi
    
    # Proceso de desinstalación
    backup_configurations
    stop_nginx_services
    remove_nginx_packages
    remove_nginx_files
    clean_repositories
    clean_firewall_rules
    verify_removal
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}✅ Desinstalación de Nginx completada${NC}"
    echo -e "${GREEN}📄 Log guardado en: $LOG_FILE${NC}"
    if [ -f "$BACKUP_DIR.tar.gz" ]; then
        echo -e "${GREEN}💾 Respaldo guardado en: $BACKUP_DIR.tar.gz${NC}"
    fi
    echo -e "${YELLOW}⚠️  Nota: Revise manualmente /var/www si contiene datos importantes${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
}

# Ejecutar función principal
main "$@"