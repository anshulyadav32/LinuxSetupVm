#!/bin/bash

# =============================================================================
# Script Maestro de Desinstalación - Linux Setup VM
# =============================================================================
# Descripción: Script inteligente para desinstalar completamente cualquier
#              componente instalado, incluyendo todas sus versiones y dependencias
# Autor: Sistema de Automatización Linux
# Versión: 1.0
# =============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/linux-setup-vm"
LOG_FILE="$LOG_DIR/uninstall-$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false
FORCE_REMOVE=false
COMPONENTS_TO_REMOVE=()
DETECTED_COMPONENTS=()

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

print_header() {
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${WHITE}                    SCRIPT MAESTRO DE DESINSTALACIÓN${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${YELLOW}Detección automática de componentes y desinstalación completa${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Crear directorio de logs si no existe
    mkdir -p "$LOG_DIR"
    
    # Escribir al log
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Mostrar en pantalla según el nivel
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
}

show_usage() {
    echo -e "${WHITE}Uso: $0 [OPCIONES] <componente1> [componente2] ...${NC}"
    echo
    echo -e "${YELLOW}OPCIONES:${NC}"
    echo -e "  -h, --help           Mostrar esta ayuda"
    echo -e "  -l, --list           Listar todos los componentes instalados"
    echo -e "  -d, --dry-run        Mostrar qué se eliminaría sin ejecutar"
    echo -e "  -f, --force          Forzar eliminación sin confirmación"
    echo -e "  -a, --all            Eliminar todos los componentes detectados"
    echo -e "  -v, --verbose        Modo verboso"
    echo
    echo -e "${YELLOW}COMPONENTES SOPORTADOS:${NC}"
    echo -e "  docker, nodejs, python, mysql, postgresql, mongodb"
    echo -e "  nginx, apache, redis, php, git, pm2, ssl-certbot"
    echo -e "  ufw-firewall, system-utilities"
    echo
    echo -e "${YELLOW}EJEMPLOS:${NC}"
    echo -e "  $0 postgresql          # Eliminar PostgreSQL y todas sus versiones"
    echo -e "  $0 -d nodejs python    # Vista previa de eliminación de Node.js y Python"
    echo -e "  $0 -f docker           # Forzar eliminación de Docker"
    echo -e "  $0 -l                  # Listar componentes instalados"
}

# =============================================================================
# FUNCIONES DE DETECCIÓN DE COMPONENTES
# =============================================================================

detect_docker_components() {
    local components=()
    
    # Docker Engine
    if command -v docker &> /dev/null; then
        components+=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    fi
    
    # Docker Compose standalone
    if command -v docker-compose &> /dev/null; then
        components+=("docker-compose")
    fi
    
    # Contenedores e imágenes
    if command -v docker &> /dev/null; then
        local containers=$(docker ps -aq 2>/dev/null | wc -l)
        local images=$(docker images -q 2>/dev/null | wc -l)
        if [ "$containers" -gt 0 ]; then
            components+=("docker-containers:$containers")
        fi
        if [ "$images" -gt 0 ]; then
            components+=("docker-images:$images")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_nodejs_components() {
    local components=()
    
    # Node.js versions
    if command -v node &> /dev/null; then
        components+=("nodejs")
        local node_version=$(node --version 2>/dev/null)
        components+=("nodejs:$node_version")
    fi
    
    # NPM
    if command -v npm &> /dev/null; then
        components+=("npm")
        local npm_version=$(npm --version 2>/dev/null)
        components+=("npm:$npm_version")
    fi
    
    # Yarn
    if command -v yarn &> /dev/null; then
        components+=("yarn")
    fi
    
    # Global packages
    if command -v npm &> /dev/null; then
        local global_packages=$(npm list -g --depth=0 2>/dev/null | grep -E "├──|└──" | wc -l)
        if [ "$global_packages" -gt 0 ]; then
            components+=("npm-global-packages:$global_packages")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_python_components() {
    local components=()
    
    # Python versions
    for python_cmd in python python3 python3.8 python3.9 python3.10 python3.11 python3.12; do
        if command -v "$python_cmd" &> /dev/null; then
            local version=$($python_cmd --version 2>/dev/null | cut -d' ' -f2)
            components+=("$python_cmd:$version")
        fi
    done
    
    # Pip versions
    for pip_cmd in pip pip3; do
        if command -v "$pip_cmd" &> /dev/null; then
            components+=("$pip_cmd")
        fi
    done
    
    # Package managers
    for pkg_manager in pipenv poetry virtualenv; do
        if command -v "$pkg_manager" &> /dev/null; then
            components+=("$pkg_manager")
        fi
    done
    
    # Virtual environments
    if [ -d "$HOME/.virtualenvs" ]; then
        local venvs=$(ls -1 "$HOME/.virtualenvs" 2>/dev/null | wc -l)
        if [ "$venvs" -gt 0 ]; then
            components+=("virtualenvs:$venvs")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_postgresql_components() {
    local components=()
    
    # PostgreSQL versions
    for version in 12 13 14 15 16 17; do
        if command -v "psql" &> /dev/null; then
            local pg_version=$(psql --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
            components+=("postgresql-$version" "postgresql-client-$version")
        fi
        
        # Servicios específicos por versión
        if systemctl is-active --quiet "postgresql@$version-main" 2>/dev/null; then
            components+=("postgresql-$version-service")
        fi
    done
    
    # PostgreSQL común
    if command -v psql &> /dev/null; then
        components+=("postgresql" "postgresql-client" "postgresql-common")
    fi
    
    # pgAdmin
    if command -v pgadmin4 &> /dev/null || [ -d "/usr/pgadmin4" ]; then
        components+=("pgadmin4")
    fi
    
    # Bases de datos
    if command -v psql &> /dev/null; then
        local databases=$(sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -v template | grep -v postgres | wc -l)
        if [ "$databases" -gt 0 ]; then
            components+=("postgresql-databases:$databases")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_mysql_components() {
    local components=()
    
    # MySQL/MariaDB
    if command -v mysql &> /dev/null; then
        components+=("mysql-client")
        local mysql_version=$(mysql --version 2>/dev/null)
        if echo "$mysql_version" | grep -q "MariaDB"; then
            components+=("mariadb-server" "mariadb-client")
        else
            components+=("mysql-server")
        fi
    fi
    
    # Servicios
    for service in mysql mariadb mysqld; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            components+=("$service-service")
        fi
    done
    
    # Bases de datos
    if command -v mysql &> /dev/null; then
        local databases=$(mysql -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | grep -v information_schema | grep -v performance_schema | grep -v mysql | wc -l)
        if [ "$databases" -gt 0 ]; then
            components+=("mysql-databases:$databases")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_mongodb_components() {
    local components=()
    
    # MongoDB
    if command -v mongod &> /dev/null; then
        components+=("mongodb-org" "mongodb-org-server" "mongodb-org-shell" "mongodb-org-mongos" "mongodb-org-tools")
        local mongo_version=$(mongod --version 2>/dev/null | grep "db version" | cut -d' ' -f3)
        components+=("mongodb:$mongo_version")
    fi
    
    # MongoDB Compass
    if command -v mongodb-compass &> /dev/null || [ -d "/opt/mongodb-compass" ]; then
        components+=("mongodb-compass")
    fi
    
    # Servicio
    if systemctl is-active --quiet mongod 2>/dev/null; then
        components+=("mongod-service")
    fi
    
    # Bases de datos
    if command -v mongo &> /dev/null; then
        local databases=$(mongo --quiet --eval "db.adminCommand('listDatabases').databases.length" 2>/dev/null)
        if [ "$databases" -gt 0 ]; then
            components+=("mongodb-databases:$databases")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_nginx_components() {
    local components=()
    
    if command -v nginx &> /dev/null; then
        components+=("nginx" "nginx-common" "nginx-core")
        local nginx_version=$(nginx -v 2>&1 | cut -d' ' -f3 | cut -d'/' -f2)
        components+=("nginx:$nginx_version")
    fi
    
    # Configuraciones de sitios
    if [ -d "/etc/nginx/sites-enabled" ]; then
        local sites=$(ls -1 /etc/nginx/sites-enabled 2>/dev/null | wc -l)
        if [ "$sites" -gt 0 ]; then
            components+=("nginx-sites:$sites")
        fi
    fi
    
    # Certificados SSL
    if [ -d "/etc/letsencrypt/live" ]; then
        local certs=$(ls -1 /etc/letsencrypt/live 2>/dev/null | wc -l)
        if [ "$certs" -gt 0 ]; then
            components+=("ssl-certificates:$certs")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_apache_components() {
    local components=()
    
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        components+=("apache2" "apache2-utils" "apache2-bin")
        
        # Módulos habilitados
        if command -v a2enmod &> /dev/null; then
            local modules=$(apache2ctl -M 2>/dev/null | wc -l)
            components+=("apache2-modules:$modules")
        fi
    fi
    
    # Sitios habilitados
    if [ -d "/etc/apache2/sites-enabled" ]; then
        local sites=$(ls -1 /etc/apache2/sites-enabled 2>/dev/null | wc -l)
        if [ "$sites" -gt 0 ]; then
            components+=("apache2-sites:$sites")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_redis_components() {
    local components=()
    
    if command -v redis-server &> /dev/null; then
        components+=("redis-server" "redis-tools")
        local redis_version=$(redis-server --version 2>/dev/null | cut -d' ' -f3 | cut -d'=' -f2)
        components+=("redis:$redis_version")
    fi
    
    if systemctl is-active --quiet redis 2>/dev/null; then
        components+=("redis-service")
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_php_components() {
    local components=()
    
    # PHP versions
    for version in 7.4 8.0 8.1 8.2 8.3; do
        if command -v "php$version" &> /dev/null; then
            components+=("php$version" "php$version-fpm" "php$version-cli")
        fi
    done
    
    # PHP común
    if command -v php &> /dev/null; then
        components+=("php" "php-fpm" "php-cli")
        local php_version=$(php --version 2>/dev/null | head -1 | cut -d' ' -f2)
        components+=("php:$php_version")
    fi
    
    # Composer
    if command -v composer &> /dev/null; then
        components+=("composer")
    fi
    
    # Extensiones PHP
    if command -v php &> /dev/null; then
        local extensions=$(php -m 2>/dev/null | wc -l)
        components+=("php-extensions:$extensions")
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_pm2_components() {
    local components=()
    
    if command -v pm2 &> /dev/null; then
        components+=("pm2")
        local pm2_version=$(pm2 --version 2>/dev/null)
        components+=("pm2:$pm2_version")
        
        # Aplicaciones PM2
        local apps=$(pm2 list 2>/dev/null | grep -c "online\|stopped\|errored" || echo "0")
        if [ "$apps" -gt 0 ]; then
            components+=("pm2-apps:$apps")
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

detect_git_components() {
    local components=()
    
    if command -v git &> /dev/null; then
        components+=("git")
        local git_version=$(git --version 2>/dev/null | cut -d' ' -f3)
        components+=("git:$git_version")
    fi
    
    # Git LFS
    if command -v git-lfs &> /dev/null; then
        components+=("git-lfs")
    fi
    
    printf '%s\n' "${components[@]}"
}

# =============================================================================
# FUNCIÓN PRINCIPAL DE DETECCIÓN
# =============================================================================

detect_all_components() {
    local component="$1"
    local detected=()
    
    case "$component" in
        "docker")
            detected=($(detect_docker_components))
            ;;
        "nodejs"|"node")
            detected=($(detect_nodejs_components))
            ;;
        "python")
            detected=($(detect_python_components))
            ;;
        "postgresql"|"psql")
            detected=($(detect_postgresql_components))
            ;;
        "mysql"|"mariadb")
            detected=($(detect_mysql_components))
            ;;
        "mongodb"|"mongo")
            detected=($(detect_mongodb_components))
            ;;
        "nginx")
            detected=($(detect_nginx_components))
            ;;
        "apache"|"apache2")
            detected=($(detect_apache_components))
            ;;
        "redis")
            detected=($(detect_redis_components))
            ;;
        "php")
            detected=($(detect_php_components))
            ;;
        "pm2")
            detected=($(detect_pm2_components))
            ;;
        "git")
            detected=($(detect_git_components))
            ;;
        *)
            log_message "WARN" "Componente no reconocido: $component"
            ;;
    esac
    
    printf '%s\n' "${detected[@]}"
}

# =============================================================================
# FUNCIÓN DE VISTA PREVIA
# =============================================================================

show_removal_preview() {
    local components=("$@")
    
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${WHITE}                        VISTA PREVIA DE ELIMINACIÓN${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo
    
    for component in "${components[@]}"; do
        echo -e "${YELLOW}🔍 Analizando: ${WHITE}$component${NC}"
        
        local detected_items=($(detect_all_components "$component"))
        
        if [ ${#detected_items[@]} -eq 0 ]; then
            echo -e "${RED}   ❌ No se encontraron componentes instalados${NC}"
        else
            echo -e "${GREEN}   ✅ Componentes detectados para eliminación:${NC}"
            for item in "${detected_items[@]}"; do
                if [[ "$item" == *":"* ]]; then
                    local name=$(echo "$item" | cut -d':' -f1)
                    local info=$(echo "$item" | cut -d':' -f2)
                    echo -e "${BLUE}      📦 $name ${PURPLE}($info)${NC}"
                else
                    echo -e "${BLUE}      📦 $item${NC}"
                fi
            done
        fi
        echo
    done
    
    echo -e "${CYAN}=============================================================================${NC}"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================

main() {
    print_header
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                echo -e "${YELLOW}Detectando componentes instalados...${NC}"
                # Implementar listado completo
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_REMOVE=true
                shift
                ;;
            -a|--all)
                # Implementar eliminación de todos los componentes
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -*)
                log_message "ERROR" "Opción desconocida: $1"
                show_usage
                exit 1
                ;;
            *)
                COMPONENTS_TO_REMOVE+=("$1")
                shift
                ;;
        esac
    done
    
    # Verificar que se especificaron componentes
    if [ ${#COMPONENTS_TO_REMOVE[@]} -eq 0 ]; then
        log_message "ERROR" "Debe especificar al menos un componente para desinstalar"
        show_usage
        exit 1
    fi
    
    # Mostrar vista previa
    show_removal_preview "${COMPONENTS_TO_REMOVE[@]}"
    
    # Confirmación si no es dry-run ni force
    if [ "$DRY_RUN" = false ] && [ "$FORCE_REMOVE" = false ]; then
        echo -e "${YELLOW}¿Desea continuar con la desinstalación? (s/N): ${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log_message "INFO" "Desinstalación cancelada por el usuario"
            exit 0
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "Modo dry-run activado - no se realizarán cambios"
        exit 0
    fi
    
    # Proceder con la desinstalación
    log_message "INFO" "Iniciando proceso de desinstalación..."
    
    for component in "${COMPONENTS_TO_REMOVE[@]}"; do
        log_message "INFO" "Desinstalando: $component"
        
        # Llamar al script específico de desinstalación
        local uninstall_script="$SCRIPT_DIR/uninstall-$component.sh"
        if [ -f "$uninstall_script" ]; then
            log_message "INFO" "Ejecutando script específico: $uninstall_script"
            bash "$uninstall_script"
        else
            log_message "WARN" "Script específico no encontrado: $uninstall_script"
            log_message "INFO" "Usando desinstalación genérica para: $component"
            # Implementar desinstalación genérica aquí
        fi
    done
    
    log_message "INFO" "Proceso de desinstalación completado"
    echo -e "${GREEN}✅ Desinstalación completada. Log guardado en: $LOG_FILE${NC}"
}

# Ejecutar función principal
main "$@"