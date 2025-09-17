#!/bin/bash

# =============================================================================
# Component Status Checker - Linux Setup VM
# =============================================================================
# Descripción: Verifica el estado de instalación de componentes específicos
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
    cat << EOF
${YELLOW}Uso:${NC} $0 [OPCIONES] [COMPONENTE]

${YELLOW}DESCRIPCIÓN:${NC}
  Verifica el estado de instalación y configuración básica de componentes

${YELLOW}OPCIONES:${NC}
  -h, --help              Mostrar esta ayuda
  -v, --verbose           Mostrar información detallada
  -q, --quiet             Modo silencioso (solo estado)
  -j, --json              Salida en formato JSON
  -l, --list              Listar todos los componentes disponibles

${YELLOW}COMPONENTES SOPORTADOS:${NC}
  docker, nodejs, nginx, mysql, postgresql, php, python, git,
  redis, mongodb, apache, pm2, ssl-certbot, ufw-firewall

${YELLOW}EJEMPLOS:${NC}
  $0 docker               # Verificar estado de Docker
  $0 --verbose nginx      # Información detallada de Nginx
  $0 --json mysql         # Salida JSON del estado de MySQL
  $0 --list               # Listar todos los componentes

EOF
}

# Verificar Docker
check_docker() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local service_status=""
    local details=""
    
    if command -v docker &>/dev/null; then
        status="INSTALLED"
        version=$(docker --version 2>/dev/null | grep -o '[0-9.]*' | head -1)
        
        if systemctl is-active docker &>/dev/null; then
            service_status="RUNNING"
            local containers=$(docker ps -q 2>/dev/null | wc -l)
            details="Contenedores activos: $containers"
        else
            service_status="STOPPED"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}Docker:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$service_status" ] && echo -e "  Servicio: $(format_service_status $service_status)"
        [ -n "$details" ] && echo -e "  Detalles: $details"
    else
        echo -e "${CYAN}Docker:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar Node.js
check_nodejs() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local npm_version=""
    local details=""
    
    if command -v node &>/dev/null; then
        status="INSTALLED"
        version=$(node --version 2>/dev/null)
        
        if command -v npm &>/dev/null; then
            npm_version=$(npm --version 2>/dev/null)
            local global_packages=$(npm list -g --depth=0 2>/dev/null | grep -c "├──\|└──" || echo "0")
            details="Paquetes globales: $global_packages"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}Node.js:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$npm_version" ] && echo -e "  npm: $npm_version"
        [ -n "$details" ] && echo -e "  Detalles: $details"
    else
        echo -e "${CYAN}Node.js:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar Nginx
check_nginx() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local service_status=""
    local config_status=""
    local details=""
    
    if command -v nginx &>/dev/null; then
        status="INSTALLED"
        version=$(nginx -v 2>&1 | grep -o 'nginx/[0-9.]*')
        
        if systemctl is-active nginx &>/dev/null; then
            service_status="RUNNING"
        else
            service_status="STOPPED"
        fi
        
        if nginx -t &>/dev/null; then
            config_status="VALID"
        else
            config_status="INVALID"
        fi
        
        if [ -d "/etc/nginx/sites-enabled" ]; then
            local sites=$(find /etc/nginx/sites-enabled -type l | wc -l)
            details="Sitios activos: $sites"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}Nginx:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$service_status" ] && echo -e "  Servicio: $(format_service_status $service_status)"
        [ -n "$config_status" ] && echo -e "  Configuración: $(format_config_status $config_status)"
        [ -n "$details" ] && echo -e "  Detalles: $details"
    else
        echo -e "${CYAN}Nginx:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar MySQL
check_mysql() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local service_status=""
    local connection_status=""
    local details=""
    
    if command -v mysql &>/dev/null; then
        status="INSTALLED"
        version=$(mysql --version 2>/dev/null | grep -o 'Ver [0-9.]*' | cut -d' ' -f2)
        
        if systemctl is-active mysql &>/dev/null; then
            service_status="RUNNING"
            
            if mysql -e "SELECT 1" &>/dev/null; then
                connection_status="OK"
                local db_count=$(mysql -e "SHOW DATABASES;" 2>/dev/null | wc -l)
                details="Bases de datos: $((db_count - 1))"
            else
                connection_status="ERROR"
            fi
        else
            service_status="STOPPED"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}MySQL:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$service_status" ] && echo -e "  Servicio: $(format_service_status $service_status)"
        [ -n "$connection_status" ] && echo -e "  Conexión: $(format_connection_status $connection_status)"
        [ -n "$details" ] && echo -e "  Detalles: $details"
    else
        echo -e "${CYAN}MySQL:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar PostgreSQL
check_postgresql() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local service_status=""
    
    if command -v psql &>/dev/null; then
        status="INSTALLED"
        version=$(psql --version 2>/dev/null | grep -o '[0-9.]*' | head -1)
        
        if systemctl is-active postgresql &>/dev/null; then
            service_status="RUNNING"
        else
            service_status="STOPPED"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}PostgreSQL:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$service_status" ] && echo -e "  Servicio: $(format_service_status $service_status)"
    else
        echo -e "${CYAN}PostgreSQL:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar PHP
check_php() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local extensions=""
    
    if command -v php &>/dev/null; then
        status="INSTALLED"
        version=$(php --version 2>/dev/null | head -1 | grep -o 'PHP [0-9.]*' | cut -d' ' -f2)
        
        if [ "$verbose" = "true" ]; then
            local ext_count=$(php -m 2>/dev/null | wc -l)
            extensions="Extensiones: $ext_count"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}PHP:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$extensions" ] && echo -e "  $extensions"
    else
        echo -e "${CYAN}PHP:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar Python
check_python() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local pip_status=""
    
    if command -v python3 &>/dev/null; then
        status="INSTALLED"
        version=$(python3 --version 2>/dev/null | grep -o '[0-9.]*')
        
        if command -v pip3 &>/dev/null; then
            pip_status="AVAILABLE"
        else
            pip_status="NOT_AVAILABLE"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}Python:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$pip_status" ] && echo -e "  pip3: $(format_pip_status $pip_status)"
    else
        echo -e "${CYAN}Python:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificar Git
check_git() {
    local verbose="$1"
    local status="NOT_INSTALLED"
    local version=""
    local config=""
    
    if command -v git &>/dev/null; then
        status="INSTALLED"
        version=$(git --version 2>/dev/null | grep -o '[0-9.]*')
        
        if [ "$verbose" = "true" ]; then
            local user_name=$(git config --global user.name 2>/dev/null || echo "No configurado")
            local user_email=$(git config --global user.email 2>/dev/null || echo "No configurado")
            config="Usuario: $user_name, Email: $user_email"
        fi
    fi
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}Git:${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$config" ] && echo -e "  Configuración: $config"
    else
        echo -e "${CYAN}Git:${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Verificación genérica para otros componentes
check_generic() {
    local component="$1"
    local verbose="$2"
    local status="NOT_INSTALLED"
    local version=""
    local service_status=""
    
    case "$component" in
        "redis")
            if command -v redis-server &>/dev/null; then
                status="INSTALLED"
                version=$(redis-server --version 2>/dev/null | grep -o 'v=[0-9.]*' | cut -d'=' -f2)
                if systemctl is-active redis &>/dev/null; then
                    service_status="RUNNING"
                else
                    service_status="STOPPED"
                fi
            fi
            ;;
        "mongodb")
            if command -v mongod &>/dev/null; then
                status="INSTALLED"
                version=$(mongod --version 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
                if systemctl is-active mongod &>/dev/null; then
                    service_status="RUNNING"
                else
                    service_status="STOPPED"
                fi
            fi
            ;;
        "apache")
            if command -v apache2 &>/dev/null; then
                status="INSTALLED"
                version=$(apache2 -v 2>/dev/null | grep -o 'Apache/[0-9.]*')
                if systemctl is-active apache2 &>/dev/null; then
                    service_status="RUNNING"
                else
                    service_status="STOPPED"
                fi
            fi
            ;;
        "pm2")
            if command -v pm2 &>/dev/null; then
                status="INSTALLED"
                version=$(pm2 --version 2>/dev/null)
            fi
            ;;
        "ssl-certbot")
            if command -v certbot &>/dev/null; then
                status="INSTALLED"
                version=$(certbot --version 2>/dev/null | grep -o '[0-9.]*')
            fi
            ;;
        "ufw-firewall")
            if command -v ufw &>/dev/null; then
                status="INSTALLED"
                version=$(ufw --version 2>/dev/null | grep -o '[0-9.]*')
            fi
            ;;
    esac
    
    if [ "$verbose" = "true" ]; then
        echo -e "${CYAN}$(echo $component | tr '[:lower:]' '[:upper:]'):${NC}"
        echo -e "  Estado: $(format_status $status)"
        [ -n "$version" ] && echo -e "  Versión: $version"
        [ -n "$service_status" ] && echo -e "  Servicio: $(format_service_status $service_status)"
    else
        echo -e "${CYAN}$(echo $component | tr '[:lower:]' '[:upper:]'):${NC} $(format_status $status)"
    fi
    
    return $(status_to_exit_code $status)
}

# Formatear estado
format_status() {
    case "$1" in
        "INSTALLED") echo -e "${GREEN}✅ INSTALADO${NC}" ;;
        "NOT_INSTALLED") echo -e "${RED}❌ NO INSTALADO${NC}" ;;
        *) echo -e "${YELLOW}❓ DESCONOCIDO${NC}" ;;
    esac
}

# Formatear estado del servicio
format_service_status() {
    case "$1" in
        "RUNNING") echo -e "${GREEN}🟢 EJECUTÁNDOSE${NC}" ;;
        "STOPPED") echo -e "${RED}🔴 DETENIDO${NC}" ;;
        *) echo -e "${YELLOW}❓ DESCONOCIDO${NC}" ;;
    esac
}

# Formatear estado de configuración
format_config_status() {
    case "$1" in
        "VALID") echo -e "${GREEN}✅ VÁLIDA${NC}" ;;
        "INVALID") echo -e "${RED}❌ INVÁLIDA${NC}" ;;
        *) echo -e "${YELLOW}❓ DESCONOCIDA${NC}" ;;
    esac
}

# Formatear estado de conexión
format_connection_status() {
    case "$1" in
        "OK") echo -e "${GREEN}✅ OK${NC}" ;;
        "ERROR") echo -e "${RED}❌ ERROR${NC}" ;;
        *) echo -e "${YELLOW}❓ DESCONOCIDO${NC}" ;;
    esac
}

# Formatear estado de pip
format_pip_status() {
    case "$1" in
        "AVAILABLE") echo -e "${GREEN}✅ DISPONIBLE${NC}" ;;
        "NOT_AVAILABLE") echo -e "${RED}❌ NO DISPONIBLE${NC}" ;;
        *) echo -e "${YELLOW}❓ DESCONOCIDO${NC}" ;;
    esac
}

# Convertir estado a código de salida
status_to_exit_code() {
    case "$1" in
        "INSTALLED") return 0 ;;
        "NOT_INSTALLED") return 1 ;;
        *) return 2 ;;
    esac
}

# Listar componentes disponibles
list_components() {
    echo -e "${YELLOW}Componentes disponibles:${NC}"
    echo -e "  ${CYAN}docker${NC}          - Docker Engine"
    echo -e "  ${CYAN}nodejs${NC}          - Node.js y npm"
    echo -e "  ${CYAN}nginx${NC}           - Servidor web Nginx"
    echo -e "  ${CYAN}mysql${NC}           - Base de datos MySQL"
    echo -e "  ${CYAN}postgresql${NC}      - Base de datos PostgreSQL"
    echo -e "  ${CYAN}php${NC}             - PHP y extensiones"
    echo -e "  ${CYAN}python${NC}          - Python 3 y pip"
    echo -e "  ${CYAN}git${NC}             - Sistema de control de versiones"
    echo -e "  ${CYAN}redis${NC}           - Base de datos Redis"
    echo -e "  ${CYAN}mongodb${NC}         - Base de datos MongoDB"
    echo -e "  ${CYAN}apache${NC}          - Servidor web Apache"
    echo -e "  ${CYAN}pm2${NC}             - Gestor de procesos PM2"
    echo -e "  ${CYAN}ssl-certbot${NC}     - Certificados SSL"
    echo -e "  ${CYAN}ufw-firewall${NC}    - Firewall UFW"
}

# Salida JSON
print_json() {
    local component="$1"
    local status="$2"
    local version="$3"
    local service_status="$4"
    
    echo "{"
    echo "  \"component\": \"$component\","
    echo "  \"status\": \"$status\","
    echo "  \"timestamp\": \"$(date -Iseconds)\""
    [ -n "$version" ] && echo "  ,\"version\": \"$version\""
    [ -n "$service_status" ] && echo "  ,\"service_status\": \"$service_status\""
    echo "}"
}

# Función principal
main() {
    local component=""
    local verbose=false
    local quiet=false
    local json_output=false
    local list_components_flag=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -j|--json)
                json_output=true
                shift
                ;;
            -l|--list)
                list_components_flag=true
                shift
                ;;
            -*)
                echo -e "${RED}Error: Opción desconocida: $1${NC}" >&2
                exit 1
                ;;
            *)
                component="$1"
                shift
                ;;
        esac
    done
    
    # Listar componentes si se solicita
    if [ "$list_components_flag" = "true" ]; then
        list_components
        exit 0
    fi
    
    # Verificar que se especificó un componente
    if [ -z "$component" ]; then
        echo -e "${RED}Error: Debe especificar un componente${NC}" >&2
        echo "Use '$0 --help' para ver la ayuda"
        exit 1
    fi
    
    # Verificar componente específico
    case "$component" in
        "docker") check_docker "$verbose" ;;
        "nodejs") check_nodejs "$verbose" ;;
        "nginx") check_nginx "$verbose" ;;
        "mysql") check_mysql "$verbose" ;;
        "postgresql") check_postgresql "$verbose" ;;
        "php") check_php "$verbose" ;;
        "python") check_python "$verbose" ;;
        "git") check_git "$verbose" ;;
        "redis"|"mongodb"|"apache"|"pm2"|"ssl-certbot"|"ufw-firewall")
            check_generic "$component" "$verbose"
            ;;
        *)
            echo -e "${RED}Error: Componente no soportado: $component${NC}" >&2
            echo "Use '$0 --list' para ver los componentes disponibles"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"