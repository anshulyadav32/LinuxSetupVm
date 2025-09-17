#!/bin/bash

# =============================================================================
# Health Checker - Linux Setup VM
# =============================================================================
# Descripción: Verifica el estado y salud de todos los componentes del sistema
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/linux-setup-vm/health-check-$(date +%Y%m%d_%H%M%S).log"

# Componentes soportados
SUPPORTED_COMPONENTS=(
    "system"
    "docker"
    "nodejs"
    "nginx"
    "mysql"
    "postgresql"
    "php"
    "python"
    "git"
    "redis"
    "mongodb"
    "apache"
    "pm2"
    "ssl-certbot"
    "ufw-firewall"
)

# Estados de salud
declare -A HEALTH_STATUS
declare -A HEALTH_DETAILS
declare -A HEALTH_RECOMMENDATIONS

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
        "SUCCESS") echo -e "${CYAN}[SUCCESS]${NC} $message" ;;
    esac
}

print_header() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${YELLOW}                    VERIFICADOR DE SALUD - LINUX SETUP VM${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

print_help() {
    cat << EOF
${YELLOW}Uso:${NC} $0 [OPCIONES] [COMPONENTE]

${YELLOW}OPCIONES:${NC}
  -h, --help              Mostrar esta ayuda
  -a, --all               Verificar todos los componentes
  -s, --summary           Mostrar solo resumen
  -d, --detailed          Mostrar información detallada
  -j, --json              Salida en formato JSON
  -f, --fix               Intentar reparar problemas automáticamente
  -w, --warnings          Mostrar solo advertencias y errores
  -q, --quiet             Modo silencioso (solo errores)

${YELLOW}COMPONENTES SOPORTADOS:${NC}
$(printf "  %-15s %s\n" \
    "system" "Sistema base y recursos" \
    "docker" "Docker Engine y contenedores" \
    "nodejs" "Node.js y npm" \
    "nginx" "Servidor web Nginx" \
    "mysql" "Base de datos MySQL" \
    "postgresql" "Base de datos PostgreSQL" \
    "php" "PHP y extensiones" \
    "python" "Python y pip" \
    "git" "Sistema de control de versiones" \
    "redis" "Base de datos Redis" \
    "mongodb" "Base de datos MongoDB" \
    "apache" "Servidor web Apache" \
    "pm2" "Gestor de procesos PM2" \
    "ssl-certbot" "Certificados SSL" \
    "ufw-firewall" "Firewall UFW")

${YELLOW}EJEMPLOS:${NC}
  $0 --all                    # Verificar todos los componentes
  $0 docker nginx             # Verificar Docker y Nginx
  $0 --summary                # Resumen rápido del sistema
  $0 --json --all             # Salida JSON de todos los componentes
  $0 --fix mysql              # Verificar y reparar MySQL

EOF
}

# Verificar si un componente está instalado
is_component_installed() {
    local component="$1"
    
    case "$component" in
        "system") return 0 ;;
        "docker") command -v docker &>/dev/null ;;
        "nodejs") command -v node &>/dev/null ;;
        "nginx") command -v nginx &>/dev/null ;;
        "mysql") command -v mysql &>/dev/null ;;
        "postgresql") command -v psql &>/dev/null ;;
        "php") command -v php &>/dev/null ;;
        "python") command -v python3 &>/dev/null ;;
        "git") command -v git &>/dev/null ;;
        "redis") command -v redis-server &>/dev/null ;;
        "mongodb") command -v mongod &>/dev/null ;;
        "apache") command -v apache2 &>/dev/null ;;
        "pm2") command -v pm2 &>/dev/null ;;
        "ssl-certbot") command -v certbot &>/dev/null ;;
        "ufw-firewall") command -v ufw &>/dev/null ;;
        *) return 1 ;;
    esac
}

# Verificar salud del sistema
check_system_health() {
    local status="HEALTHY"
    local details=""
    local recommendations=""
    
    # Verificar uso de CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        status="WARNING"
        details+="CPU: ${cpu_usage}% (Alto uso) "
        recommendations+="Revisar procesos con 'top' o 'htop'. "
    else
        details+="CPU: ${cpu_usage}% "
    fi
    
    # Verificar uso de memoria
    local mem_info=$(free | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$(( mem_used * 100 / mem_total ))
    
    if [ $mem_percent -gt 85 ]; then
        status="CRITICAL"
        details+="RAM: ${mem_percent}% (Crítico) "
        recommendations+="Liberar memoria o agregar más RAM. "
    elif [ $mem_percent -gt 70 ]; then
        status="WARNING"
        details+="RAM: ${mem_percent}% (Alto uso) "
        recommendations+="Monitorear uso de memoria. "
    else
        details+="RAM: ${mem_percent}% "
    fi
    
    # Verificar espacio en disco
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $disk_usage -gt 90 ]; then
        status="CRITICAL"
        details+="Disco: ${disk_usage}% (Crítico) "
        recommendations+="Liberar espacio en disco urgentemente. "
    elif [ $disk_usage -gt 80 ]; then
        status="WARNING"
        details+="Disco: ${disk_usage}% (Alto uso) "
        recommendations+="Considerar limpiar archivos temporales. "
    else
        details+="Disco: ${disk_usage}% "
    fi
    
    # Verificar carga del sistema
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    if (( $(echo "$load_avg > $cpu_cores" | bc -l) )); then
        status="WARNING"
        details+="Carga: ${load_avg}/${cpu_cores} (Alta) "
        recommendations+="Sistema sobrecargado, revisar procesos. "
    else
        details+="Carga: ${load_avg}/${cpu_cores} "
    fi
    
    # Verificar tiempo de actividad
    local uptime_info=$(uptime -p)
    details+="Uptime: $uptime_info "
    
    HEALTH_STATUS["system"]="$status"
    HEALTH_DETAILS["system"]="$details"
    HEALTH_RECOMMENDATIONS["system"]="$recommendations"
}

# Verificar salud de Docker
check_docker_health() {
    local status="HEALTHY"
    local details=""
    local recommendations=""
    
    if ! is_component_installed "docker"; then
        HEALTH_STATUS["docker"]="NOT_INSTALLED"
        return
    fi
    
    # Verificar servicio Docker
    if ! systemctl is-active docker &>/dev/null; then
        status="CRITICAL"
        details+="Servicio: Detenido "
        recommendations+="Iniciar servicio Docker: 'sudo systemctl start docker'. "
    else
        details+="Servicio: Activo "
    fi
    
    # Verificar versión
    local version=$(docker --version 2>/dev/null | grep -o '[0-9.]*' | head -1)
    details+="Versión: $version "
    
    # Verificar contenedores
    local containers_running=$(docker ps -q 2>/dev/null | wc -l)
    local containers_total=$(docker ps -aq 2>/dev/null | wc -l)
    details+="Contenedores: ${containers_running}/${containers_total} ejecutándose "
    
    # Verificar imágenes
    local images_count=$(docker images -q 2>/dev/null | wc -l)
    details+="Imágenes: $images_count "
    
    # Verificar espacio usado por Docker
    local docker_size=$(docker system df 2>/dev/null | tail -n +2 | awk '{sum += $3} END {print sum}')
    if [ -n "$docker_size" ] && [ "$docker_size" -gt 10 ]; then
        recommendations+="Considerar limpiar imágenes no usadas: 'docker system prune'. "
    fi
    
    HEALTH_STATUS["docker"]="$status"
    HEALTH_DETAILS["docker"]="$details"
    HEALTH_RECOMMENDATIONS["docker"]="$recommendations"
}

# Verificar salud de Node.js
check_nodejs_health() {
    local status="HEALTHY"
    local details=""
    local recommendations=""
    
    if ! is_component_installed "nodejs"; then
        HEALTH_STATUS["nodejs"]="NOT_INSTALLED"
        return
    fi
    
    # Verificar versión de Node.js
    local node_version=$(node --version 2>/dev/null)
    details+="Node.js: $node_version "
    
    # Verificar npm
    if command -v npm &>/dev/null; then
        local npm_version=$(npm --version 2>/dev/null)
        details+="npm: $npm_version "
        
        # Verificar paquetes globales
        local global_packages=$(npm list -g --depth=0 2>/dev/null | grep -c "├──\|└──" || echo "0")
        details+="Paquetes globales: $global_packages "
    else
        status="WARNING"
        details+="npm: No disponible "
        recommendations+="Instalar npm. "
    fi
    
    # Verificar PM2 si está instalado
    if command -v pm2 &>/dev/null; then
        local pm2_processes=$(pm2 list 2>/dev/null | grep -c "online\|stopped" || echo "0")
        details+="Procesos PM2: $pm2_processes "
    fi
    
    HEALTH_STATUS["nodejs"]="$status"
    HEALTH_DETAILS["nodejs"]="$details"
    HEALTH_RECOMMENDATIONS["nodejs"]="$recommendations"
}

# Verificar salud de Nginx
check_nginx_health() {
    local status="HEALTHY"
    local details=""
    local recommendations=""
    
    if ! is_component_installed "nginx"; then
        HEALTH_STATUS["nginx"]="NOT_INSTALLED"
        return
    fi
    
    # Verificar servicio
    if ! systemctl is-active nginx &>/dev/null; then
        status="CRITICAL"
        details+="Servicio: Detenido "
        recommendations+="Iniciar Nginx: 'sudo systemctl start nginx'. "
    else
        details+="Servicio: Activo "
        
        # Verificar configuración
        if nginx -t &>/dev/null; then
            details+="Configuración: Válida "
        else
            status="WARNING"
            details+="Configuración: Errores "
            recommendations+="Revisar configuración: 'nginx -t'. "
        fi
    fi
    
    # Verificar versión
    local version=$(nginx -v 2>&1 | grep -o 'nginx/[0-9.]*')
    details+="Versión: $version "
    
    # Verificar sitios habilitados
    if [ -d "/etc/nginx/sites-enabled" ]; then
        local sites_count=$(find /etc/nginx/sites-enabled -type l | wc -l)
        details+="Sitios activos: $sites_count "
    fi
    
    # Verificar puertos
    if netstat -tlnp 2>/dev/null | grep -q ":80.*nginx"; then
        details+="Puerto 80: Activo "
    fi
    if netstat -tlnp 2>/dev/null | grep -q ":443.*nginx"; then
        details+="Puerto 443: Activo "
    fi
    
    HEALTH_STATUS["nginx"]="$status"
    HEALTH_DETAILS["nginx"]="$details"
    HEALTH_RECOMMENDATIONS["nginx"]="$recommendations"
}

# Verificar salud de MySQL
check_mysql_health() {
    local status="HEALTHY"
    local details=""
    local recommendations=""
    
    if ! is_component_installed "mysql"; then
        HEALTH_STATUS["mysql"]="NOT_INSTALLED"
        return
    fi
    
    # Verificar servicio
    if ! systemctl is-active mysql &>/dev/null; then
        status="CRITICAL"
        details+="Servicio: Detenido "
        recommendations+="Iniciar MySQL: 'sudo systemctl start mysql'. "
    else
        details+="Servicio: Activo "
        
        # Verificar conexión
        if mysql -e "SELECT 1" &>/dev/null; then
            details+="Conexión: OK "
            
            # Verificar bases de datos
            local db_count=$(mysql -e "SHOW DATABASES;" 2>/dev/null | wc -l)
            details+="Bases de datos: $((db_count - 1)) "
            
        else
            status="WARNING"
            details+="Conexión: Error "
            recommendations+="Verificar credenciales de MySQL. "
        fi
    fi
    
    # Verificar versión
    local version=$(mysql --version 2>/dev/null | grep -o 'Ver [0-9.]*' | cut -d' ' -f2)
    details+="Versión: $version "
    
    HEALTH_STATUS["mysql"]="$status"
    HEALTH_DETAILS["mysql"]="$details"
    HEALTH_RECOMMENDATIONS["mysql"]="$recommendations"
}

# Función genérica para verificar otros componentes
check_generic_health() {
    local component="$1"
    local status="HEALTHY"
    local details=""
    local recommendations=""
    
    if ! is_component_installed "$component"; then
        HEALTH_STATUS["$component"]="NOT_INSTALLED"
        return
    fi
    
    # Verificar versión según el componente
    case "$component" in
        "postgresql")
            local version=$(psql --version 2>/dev/null | grep -o '[0-9.]*' | head -1)
            details+="Versión: $version "
            if systemctl is-active postgresql &>/dev/null; then
                details+="Servicio: Activo "
            else
                status="WARNING"
                details+="Servicio: Inactivo "
            fi
            ;;
        "php")
            local version=$(php --version 2>/dev/null | head -1 | grep -o 'PHP [0-9.]*' | cut -d' ' -f2)
            details+="Versión: $version "
            ;;
        "python")
            local version=$(python3 --version 2>/dev/null | grep -o '[0-9.]*')
            details+="Versión: $version "
            if command -v pip3 &>/dev/null; then
                details+="pip3: Disponible "
            fi
            ;;
        "git")
            local version=$(git --version 2>/dev/null | grep -o '[0-9.]*')
            details+="Versión: $version "
            ;;
        "redis")
            local version=$(redis-server --version 2>/dev/null | grep -o 'v=[0-9.]*' | cut -d'=' -f2)
            details+="Versión: $version "
            if systemctl is-active redis &>/dev/null; then
                details+="Servicio: Activo "
            fi
            ;;
        *)
            details+="Instalado "
            ;;
    esac
    
    HEALTH_STATUS["$component"]="$status"
    HEALTH_DETAILS["$component"]="$details"
    HEALTH_RECOMMENDATIONS["$component"]="$recommendations"
}

# Mostrar estado con colores
print_status() {
    local status="$1"
    case "$status" in
        "HEALTHY") echo -e "${GREEN}✅ SALUDABLE${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  ADVERTENCIA${NC}" ;;
        "CRITICAL") echo -e "${RED}❌ CRÍTICO${NC}" ;;
        "NOT_INSTALLED") echo -e "${BLUE}➖ NO INSTALADO${NC}" ;;
        *) echo -e "${PURPLE}❓ DESCONOCIDO${NC}" ;;
    esac
}

# Mostrar resumen
print_summary() {
    local healthy=0
    local warnings=0
    local critical=0
    local not_installed=0
    
    for component in "${!HEALTH_STATUS[@]}"; do
        case "${HEALTH_STATUS[$component]}" in
            "HEALTHY") ((healthy++)) ;;
            "WARNING") ((warnings++)) ;;
            "CRITICAL") ((critical++)) ;;
            "NOT_INSTALLED") ((not_installed++)) ;;
        esac
    done
    
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${YELLOW}                           RESUMEN DE SALUD${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${GREEN}✅ Saludables: $healthy${NC}"
    echo -e "${YELLOW}⚠️  Advertencias: $warnings${NC}"
    echo -e "${RED}❌ Críticos: $critical${NC}"
    echo -e "${BLUE}➖ No instalados: $not_installed${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Salida JSON
print_json() {
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"components\": {"
    
    local first=true
    for component in "${!HEALTH_STATUS[@]}"; do
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false
        
        echo "    \"$component\": {"
        echo "      \"status\": \"${HEALTH_STATUS[$component]}\","
        echo "      \"details\": \"${HEALTH_DETAILS[$component]}\","
        echo "      \"recommendations\": \"${HEALTH_RECOMMENDATIONS[$component]}\""
        echo -n "    }"
    done
    
    echo ""
    echo "  }"
    echo "}"
}

# Función principal
main() {
    local components=()
    local all_components=false
    local summary_only=false
    local detailed=false
    local json_output=false
    local fix_issues=false
    local warnings_only=false
    local quiet=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help
                exit 0
                ;;
            -a|--all)
                all_components=true
                shift
                ;;
            -s|--summary)
                summary_only=true
                shift
                ;;
            -d|--detailed)
                detailed=true
                shift
                ;;
            -j|--json)
                json_output=true
                shift
                ;;
            -f|--fix)
                fix_issues=true
                shift
                ;;
            -w|--warnings)
                warnings_only=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -*)
                log_message "ERROR" "Opción desconocida: $1"
                exit 1
                ;;
            *)
                if [[ " ${SUPPORTED_COMPONENTS[@]} " =~ " $1 " ]]; then
                    components+=("$1")
                else
                    log_message "ERROR" "Componente no soportado: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Determinar componentes a verificar
    if [ "$all_components" = "true" ]; then
        components=("${SUPPORTED_COMPONENTS[@]}")
    elif [ ${#components[@]} -eq 0 ]; then
        components=("${SUPPORTED_COMPONENTS[@]}")
    fi
    
    if [ "$quiet" != "true" ] && [ "$json_output" != "true" ]; then
        print_header
    fi
    
    # Verificar salud de cada componente
    for component in "${components[@]}"; do
        case "$component" in
            "system") check_system_health ;;
            "docker") check_docker_health ;;
            "nodejs") check_nodejs_health ;;
            "nginx") check_nginx_health ;;
            "mysql") check_mysql_health ;;
            *) check_generic_health "$component" ;;
        esac
    done
    
    # Mostrar resultados
    if [ "$json_output" = "true" ]; then
        print_json
    elif [ "$summary_only" = "true" ]; then
        print_summary
    else
        # Mostrar detalles de cada componente
        for component in "${components[@]}"; do
            local status="${HEALTH_STATUS[$component]}"
            
            # Filtrar por advertencias si se solicita
            if [ "$warnings_only" = "true" ] && [ "$status" = "HEALTHY" ]; then
                continue
            fi
            
            if [ "$quiet" = "true" ] && [ "$status" != "CRITICAL" ] && [ "$status" != "WARNING" ]; then
                continue
            fi
            
            echo -e "${CYAN}$component:${NC} $(print_status "$status")"
            
            if [ "$detailed" = "true" ] || [ "$status" != "HEALTHY" ]; then
                if [ -n "${HEALTH_DETAILS[$component]}" ]; then
                    echo -e "  ${BLUE}Detalles:${NC} ${HEALTH_DETAILS[$component]}"
                fi
                if [ -n "${HEALTH_RECOMMENDATIONS[$component]}" ]; then
                    echo -e "  ${YELLOW}Recomendaciones:${NC} ${HEALTH_RECOMMENDATIONS[$component]}"
                fi
            fi
            echo
        done
        
        if [ "$quiet" != "true" ]; then
            print_summary
        fi
    fi
    
    # Determinar código de salida
    local exit_code=0
    for status in "${HEALTH_STATUS[@]}"; do
        case "$status" in
            "CRITICAL") exit_code=2 ;;
            "WARNING") [ $exit_code -eq 0 ] && exit_code=1 ;;
        esac
    done
    
    exit $exit_code
}

# Ejecutar función principal
main "$@"