nt #!/bin/bash

# =============================================================================
# Script de Desinstalación PostgreSQL - Linux Setup VM
# =============================================================================
# Descripción: Desinstala completamente PostgreSQL incluyendo todas las versiones
#              (psql12, psql13, psql14, psql15, psql16, psql17, etc.)
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/linux-setup-vm/uninstall-postgresql-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/postgresql-backup-$(date +%Y%m%d_%H%M%S)"

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
    echo -e "${YELLOW}                    DESINSTALACIÓN POSTGRESQL${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Detectar todas las versiones de PostgreSQL instaladas
detect_postgresql_versions() {
    local versions=()
    
    # Buscar versiones específicas
    for version in 12 13 14 15 16 17 18; do
        if dpkg -l | grep -q "postgresql-$version" 2>/dev/null; then
            versions+=("$version")
        fi
    done
    
    printf '%s\n' "${versions[@]}"
}

# Detectar paquetes PostgreSQL instalados
detect_postgresql_packages() {
    local packages=()
    
    # Paquetes base
    for pkg in postgresql postgresql-client postgresql-common postgresql-contrib; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=("$pkg")
        fi
    done
    
    # Paquetes por versión
    local versions=($(detect_postgresql_versions))
    for version in "${versions[@]}"; do
        for pkg in "postgresql-$version" "postgresql-client-$version" "postgresql-contrib-$version" \
                   "postgresql-$version-postgis" "postgresql-$version-postgis-scripts"; do
            if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
                packages+=("$pkg")
            fi
        done
    done
    
    # pgAdmin
    for pkg in pgadmin4 pgadmin4-web pgadmin4-desktop; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=("$pkg")
        fi
    done
    
    printf '%s\n' "${packages[@]}"
}

# Detectar bases de datos
detect_databases() {
    local databases=()
    
    if command -v sudo &> /dev/null && sudo -u postgres psql -c '\l' &> /dev/null; then
        while IFS= read -r db; do
            if [[ "$db" != "template0" && "$db" != "template1" && "$db" != "postgres" && -n "$db" ]]; then
                databases+=("$db")
            fi
        done < <(sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | sed 's/^ *//g' | grep -v '^$')
    fi
    
    printf '%s\n' "${databases[@]}"
}

# Crear backup de bases de datos
backup_databases() {
    local databases=($(detect_databases))
    
    if [ ${#databases[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron bases de datos para respaldar"
        return 0
    fi
    
    log_message "INFO" "Creando respaldo de bases de datos en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    for db in "${databases[@]}"; do
        log_message "INFO" "Respaldando base de datos: $db"
        if sudo -u postgres pg_dump "$db" > "$BACKUP_DIR/$db.sql" 2>/dev/null; then
            log_message "INFO" "✅ Respaldo exitoso: $db.sql"
        else
            log_message "ERROR" "❌ Error al respaldar: $db"
        fi
    done
    
    # Respaldar usuarios y roles
    log_message "INFO" "Respaldando usuarios y roles"
    sudo -u postgres pg_dumpall --roles-only > "$BACKUP_DIR/roles.sql" 2>/dev/null
    
    # Comprimir respaldos
    tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null
    rm -rf "$BACKUP_DIR"
    
    log_message "INFO" "✅ Respaldo comprimido guardado en: $BACKUP_DIR.tar.gz"
}

# Detener servicios PostgreSQL
stop_postgresql_services() {
    log_message "INFO" "Deteniendo servicios PostgreSQL..."
    
    # Servicios generales
    for service in postgresql postgresql.service; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "INFO" "Deteniendo servicio: $service"
            sudo systemctl stop "$service" 2>/dev/null
            sudo systemctl disable "$service" 2>/dev/null
        fi
    done
    
    # Servicios por versión
    local versions=($(detect_postgresql_versions))
    for version in "${versions[@]}"; do
        for service in "postgresql@$version-main" "postgresql-$version"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                log_message "INFO" "Deteniendo servicio: $service"
                sudo systemctl stop "$service" 2>/dev/null
                sudo systemctl disable "$service" 2>/dev/null
            fi
        done
    done
}

# Eliminar paquetes PostgreSQL
remove_postgresql_packages() {
    local packages=($(detect_postgresql_packages))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron paquetes PostgreSQL para eliminar"
        return 0
    fi
    
    log_message "INFO" "Eliminando paquetes PostgreSQL..."
    
    # Mostrar paquetes a eliminar
    echo -e "${YELLOW}Paquetes que serán eliminados:${NC}"
    for pkg in "${packages[@]}"; do
        echo -e "${RED}  - $pkg${NC}"
    done
    
    # Eliminar paquetes
    log_message "INFO" "Ejecutando: apt-get remove --purge ${packages[*]}"
    sudo apt-get remove --purge -y "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Autoremove
    log_message "INFO" "Eliminando dependencias no utilizadas..."
    sudo apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
}

# Eliminar directorios y archivos
remove_postgresql_files() {
    log_message "INFO" "Eliminando directorios y archivos PostgreSQL..."
    
    # Directorios de datos
    local data_dirs=(
        "/var/lib/postgresql"
        "/etc/postgresql"
        "/var/log/postgresql"
        "/run/postgresql"
    )
    
    for dir in "${data_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_message "INFO" "Eliminando directorio: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    # Archivos de configuración
    local config_files=(
        "/etc/postgresql"
        "/etc/pgadmin"
        "/var/lib/pgadmin"
    )
    
    for file in "${config_files[@]}"; do
        if [ -e "$file" ]; then
            log_message "INFO" "Eliminando: $file"
            sudo rm -rf "$file"
        fi
    done
    
    # Usuario postgres
    if id "postgres" &>/dev/null; then
        log_message "INFO" "Eliminando usuario postgres"
        sudo deluser --remove-home postgres 2>/dev/null || true
    fi
    
    # Grupo postgres
    if getent group postgres &>/dev/null; then
        log_message "INFO" "Eliminando grupo postgres"
        sudo delgroup postgres 2>/dev/null || true
    fi
}

# Limpiar repositorios
clean_repositories() {
    log_message "INFO" "Limpiando repositorios PostgreSQL..."
    
    # Eliminar claves GPG
    local keys=(
        "B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8"
        "7FCC7D46ACCC4CF8"
    )
    
    for key in "${keys[@]}"; do
        if apt-key list 2>/dev/null | grep -q "$key"; then
            log_message "INFO" "Eliminando clave GPG: $key"
            sudo apt-key del "$key" 2>/dev/null || true
        fi
    done
    
    # Eliminar archivos de repositorio
    local repo_files=(
        "/etc/apt/sources.list.d/pgdg.list"
        "/etc/apt/sources.list.d/postgresql.list"
        "/etc/apt/sources.list.d/pgadmin4.list"
    )
    
    for file in "${repo_files[@]}"; do
        if [ -f "$file" ]; then
            log_message "INFO" "Eliminando archivo de repositorio: $file"
            sudo rm -f "$file"
        fi
    done
    
    # Actualizar cache de paquetes
    log_message "INFO" "Actualizando cache de paquetes..."
    sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
}

# Verificar desinstalación
verify_removal() {
    log_message "INFO" "Verificando desinstalación..."
    
    local issues=0
    
    # Verificar comandos
    for cmd in psql pg_dump createdb dropdb; do
        if command -v "$cmd" &> /dev/null; then
            log_message "WARN" "⚠️  Comando aún disponible: $cmd"
            ((issues++))
        fi
    done
    
    # Verificar servicios
    for service in postgresql postgresql.service; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "WARN" "⚠️  Servicio aún activo: $service"
            ((issues++))
        fi
    done
    
    # Verificar directorios
    for dir in "/var/lib/postgresql" "/etc/postgresql"; do
        if [ -d "$dir" ]; then
            log_message "WARN" "⚠️  Directorio aún existe: $dir"
            ((issues++))
        fi
    done
    
    # Verificar paquetes
    local remaining_packages=($(detect_postgresql_packages))
    if [ ${#remaining_packages[@]} -gt 0 ]; then
        log_message "WARN" "⚠️  Paquetes aún instalados: ${remaining_packages[*]}"
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
    
    # Verificar si PostgreSQL está instalado
    if ! command -v psql &> /dev/null && [ ${#$(detect_postgresql_packages)} -eq 0 ]; then
        log_message "INFO" "PostgreSQL no está instalado en el sistema"
        exit 0
    fi
    
    log_message "INFO" "Iniciando desinstalación de PostgreSQL..."
    
    # Mostrar componentes detectados
    echo -e "${YELLOW}Componentes PostgreSQL detectados:${NC}"
    
    local versions=($(detect_postgresql_versions))
    if [ ${#versions[@]} -gt 0 ]; then
        echo -e "${BLUE}Versiones: ${versions[*]}${NC}"
    fi
    
    local packages=($(detect_postgresql_packages))
    if [ ${#packages[@]} -gt 0 ]; then
        echo -e "${BLUE}Paquetes: ${#packages[@]} paquetes${NC}"
    fi
    
    local databases=($(detect_databases))
    if [ ${#databases[@]} -gt 0 ]; then
        echo -e "${BLUE}Bases de datos: ${databases[*]}${NC}"
    fi
    
    echo
    
    # Confirmación
    echo -e "${YELLOW}¿Desea continuar con la desinstalación completa de PostgreSQL? (s/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log_message "INFO" "Desinstalación cancelada por el usuario"
        exit 0
    fi
    
    # Proceso de desinstalación
    backup_databases
    stop_postgresql_services
    remove_postgresql_packages
    remove_postgresql_files
    clean_repositories
    verify_removal
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}✅ Desinstalación de PostgreSQL completada${NC}"
    echo -e "${GREEN}📄 Log guardado en: $LOG_FILE${NC}"
    if [ -f "$BACKUP_DIR.tar.gz" ]; then
        echo -e "${GREEN}💾 Respaldo guardado en: $BACKUP_DIR.tar.gz${NC}"
    fi
    echo -e "${GREEN}=============================================================================${NC}"
}

# Ejecutar función principal
main "$@"