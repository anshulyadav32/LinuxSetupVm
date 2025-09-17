#!/bin/bash

# =============================================================================
# Script de Desinstalación Docker - Linux Setup VM
# =============================================================================
# Descripción: Desinstala completamente Docker incluyendo contenedores, imágenes,
#              volúmenes, redes y todos los componentes relacionados
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/linux-setup-vm/uninstall-docker-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/docker-backup-$(date +%Y%m%d_%H%M%S)"

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
    echo -e "${YELLOW}                      DESINSTALACIÓN DOCKER${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Detectar componentes Docker
detect_docker_components() {
    local components=()
    
    # Verificar Docker Engine
    if command -v docker &> /dev/null; then
        components+=("docker-engine")
        local version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
        log_message "INFO" "Docker Engine detectado: $version"
    fi
    
    # Verificar Docker Compose
    if command -v docker-compose &> /dev/null; then
        components+=("docker-compose")
        local version=$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
        log_message "INFO" "Docker Compose detectado: $version"
    fi
    
    # Verificar contenedores
    if command -v docker &> /dev/null; then
        local containers=$(docker ps -aq 2>/dev/null | wc -l)
        if [ "$containers" -gt 0 ]; then
            components+=("containers:$containers")
            log_message "INFO" "Contenedores detectados: $containers"
        fi
        
        # Verificar imágenes
        local images=$(docker images -q 2>/dev/null | wc -l)
        if [ "$images" -gt 0 ]; then
            components+=("images:$images")
            log_message "INFO" "Imágenes detectadas: $images"
        fi
        
        # Verificar volúmenes
        local volumes=$(docker volume ls -q 2>/dev/null | wc -l)
        if [ "$volumes" -gt 0 ]; then
            components+=("volumes:$volumes")
            log_message "INFO" "Volúmenes detectados: $volumes"
        fi
        
        # Verificar redes
        local networks=$(docker network ls --filter type=custom -q 2>/dev/null | wc -l)
        if [ "$networks" -gt 0 ]; then
            components+=("networks:$networks")
            log_message "INFO" "Redes personalizadas detectadas: $networks"
        fi
    fi
    
    printf '%s\n' "${components[@]}"
}

# Detectar paquetes Docker instalados
detect_docker_packages() {
    local packages=()
    
    # Paquetes Docker oficiales
    for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=("$pkg")
        fi
    done
    
    # Paquetes Docker antiguos
    for pkg in docker docker.io docker-engine runc; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=("$pkg")
        fi
    done
    
    # Docker Compose standalone
    if command -v docker-compose &> /dev/null && [ ! -f "/usr/libexec/docker/cli-plugins/docker-compose" ]; then
        packages+=("docker-compose")
    fi
    
    printf '%s\n' "${packages[@]}"
}

# Crear backup de contenedores importantes
backup_containers() {
    if ! command -v docker &> /dev/null; then
        log_message "INFO" "Docker no disponible, omitiendo backup"
        return 0
    fi
    
    local containers=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null)
    
    if [ -z "$containers" ] || [ "$(echo "$containers" | wc -l)" -le 1 ]; then
        log_message "INFO" "No se encontraron contenedores para respaldar"
        return 0
    fi
    
    log_message "INFO" "Creando respaldo de información de contenedores en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Listar contenedores
    docker ps -a > "$BACKUP_DIR/containers.txt" 2>/dev/null
    
    # Listar imágenes
    docker images > "$BACKUP_DIR/images.txt" 2>/dev/null
    
    # Listar volúmenes
    docker volume ls > "$BACKUP_DIR/volumes.txt" 2>/dev/null
    
    # Listar redes
    docker network ls > "$BACKUP_DIR/networks.txt" 2>/dev/null
    
    # Exportar configuraciones de Docker Compose si existen
    find /home -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | while read -r compose_file; do
        local dir_name=$(basename "$(dirname "$compose_file")")
        cp "$compose_file" "$BACKUP_DIR/compose-$dir_name.yml" 2>/dev/null
    done
    
    # Comprimir respaldo
    tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null
    rm -rf "$BACKUP_DIR"
    
    log_message "INFO" "✅ Respaldo guardado en: $BACKUP_DIR.tar.gz"
}

# Detener y eliminar contenedores
remove_containers() {
    if ! command -v docker &> /dev/null; then
        return 0
    fi
    
    log_message "INFO" "Deteniendo y eliminando contenedores..."
    
    # Detener todos los contenedores en ejecución
    local running_containers=$(docker ps -q 2>/dev/null)
    if [ -n "$running_containers" ]; then
        log_message "INFO" "Deteniendo contenedores en ejecución..."
        docker stop $running_containers 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Eliminar todos los contenedores
    local all_containers=$(docker ps -aq 2>/dev/null)
    if [ -n "$all_containers" ]; then
        log_message "INFO" "Eliminando todos los contenedores..."
        docker rm -f $all_containers 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Eliminar imágenes
remove_images() {
    if ! command -v docker &> /dev/null; then
        return 0
    fi
    
    log_message "INFO" "Eliminando imágenes Docker..."
    
    # Eliminar todas las imágenes
    local images=$(docker images -aq 2>/dev/null)
    if [ -n "$images" ]; then
        log_message "INFO" "Eliminando todas las imágenes..."
        docker rmi -f $images 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Limpiar imágenes huérfanas
    docker image prune -af 2>&1 | tee -a "$LOG_FILE"
}

# Eliminar volúmenes
remove_volumes() {
    if ! command -v docker &> /dev/null; then
        return 0
    fi
    
    log_message "INFO" "Eliminando volúmenes Docker..."
    
    # Eliminar todos los volúmenes
    local volumes=$(docker volume ls -q 2>/dev/null)
    if [ -n "$volumes" ]; then
        log_message "INFO" "Eliminando todos los volúmenes..."
        docker volume rm -f $volumes 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Limpiar volúmenes huérfanos
    docker volume prune -af 2>&1 | tee -a "$LOG_FILE"
}

# Eliminar redes
remove_networks() {
    if ! command -v docker &> /dev/null; then
        return 0
    fi
    
    log_message "INFO" "Eliminando redes Docker personalizadas..."
    
    # Eliminar redes personalizadas (excepto las predeterminadas)
    local networks=$(docker network ls --filter type=custom -q 2>/dev/null)
    if [ -n "$networks" ]; then
        log_message "INFO" "Eliminando redes personalizadas..."
        docker network rm $networks 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Limpiar redes huérfanas
    docker network prune -af 2>&1 | tee -a "$LOG_FILE"
}

# Detener servicios Docker
stop_docker_services() {
    log_message "INFO" "Deteniendo servicios Docker..."
    
    # Servicios Docker
    for service in docker docker.service docker.socket containerd containerd.service; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "INFO" "Deteniendo servicio: $service"
            sudo systemctl stop "$service" 2>/dev/null
            sudo systemctl disable "$service" 2>/dev/null
        fi
    done
}

# Eliminar paquetes Docker
remove_docker_packages() {
    local packages=($(detect_docker_packages))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron paquetes Docker para eliminar"
        return 0
    fi
    
    log_message "INFO" "Eliminando paquetes Docker..."
    
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

# Eliminar directorios y archivos Docker
remove_docker_files() {
    log_message "INFO" "Eliminando directorios y archivos Docker..."
    
    # Directorios principales de Docker
    local docker_dirs=(
        "/var/lib/docker"
        "/var/lib/containerd"
        "/etc/docker"
        "/etc/containerd"
        "/var/run/docker"
        "/var/run/docker.sock"
        "/usr/local/bin/docker-compose"
    )
    
    for dir in "${docker_dirs[@]}"; do
        if [ -e "$dir" ]; then
            log_message "INFO" "Eliminando: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    # Archivos de configuración de usuario
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            local docker_config="$user_home/.docker"
            if [ -d "$docker_config" ]; then
                log_message "INFO" "Eliminando configuración de usuario: $docker_config"
                rm -rf "$docker_config"
            fi
        fi
    done
    
    # Eliminar grupo docker
    if getent group docker &>/dev/null; then
        log_message "INFO" "Eliminando grupo docker"
        sudo delgroup docker 2>/dev/null || true
    fi
}

# Limpiar repositorios Docker
clean_repositories() {
    log_message "INFO" "Limpiando repositorios Docker..."
    
    # Eliminar claves GPG de Docker
    local keys=(
        "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
        "0EBFCD88"
    )
    
    for key in "${keys[@]}"; do
        if apt-key list 2>/dev/null | grep -q "$key"; then
            log_message "INFO" "Eliminando clave GPG: $key"
            sudo apt-key del "$key" 2>/dev/null || true
        fi
    done
    
    # Eliminar archivos de repositorio
    local repo_files=(
        "/etc/apt/sources.list.d/docker.list"
        "/etc/apt/sources.list.d/docker-ce.list"
        "/etc/apt/keyrings/docker.gpg"
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
    for cmd in docker docker-compose; do
        if command -v "$cmd" &> /dev/null; then
            log_message "WARN" "⚠️  Comando aún disponible: $cmd"
            ((issues++))
        fi
    done
    
    # Verificar servicios
    for service in docker docker.service containerd; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_message "WARN" "⚠️  Servicio aún activo: $service"
            ((issues++))
        fi
    done
    
    # Verificar directorios
    for dir in "/var/lib/docker" "/etc/docker"; do
        if [ -d "$dir" ]; then
            log_message "WARN" "⚠️  Directorio aún existe: $dir"
            ((issues++))
        fi
    done
    
    # Verificar paquetes
    local remaining_packages=($(detect_docker_packages))
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
    
    # Verificar si Docker está instalado
    if ! command -v docker &> /dev/null && [ ${#$(detect_docker_packages)} -eq 0 ]; then
        log_message "INFO" "Docker no está instalado en el sistema"
        exit 0
    fi
    
    log_message "INFO" "Iniciando desinstalación de Docker..."
    
    # Mostrar componentes detectados
    echo -e "${YELLOW}Componentes Docker detectados:${NC}"
    local components=($(detect_docker_components))
    for component in "${components[@]}"; do
        if [[ "$component" == *":"* ]]; then
            local name=$(echo "$component" | cut -d':' -f1)
            local count=$(echo "$component" | cut -d':' -f2)
            echo -e "${BLUE}  - $name: $count${NC}"
        else
            echo -e "${BLUE}  - $component${NC}"
        fi
    done
    
    local packages=($(detect_docker_packages))
    if [ ${#packages[@]} -gt 0 ]; then
        echo -e "${BLUE}  - Paquetes: ${#packages[@]} paquetes${NC}"
    fi
    
    echo
    
    # Confirmación
    echo -e "${YELLOW}¿Desea continuar con la desinstalación completa de Docker? (s/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log_message "INFO" "Desinstalación cancelada por el usuario"
        exit 0
    fi
    
    # Proceso de desinstalación
    backup_containers
    remove_containers
    remove_images
    remove_volumes
    remove_networks
    stop_docker_services
    remove_docker_packages
    remove_docker_files
    clean_repositories
    verify_removal
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}✅ Desinstalación de Docker completada${NC}"
    echo -e "${GREEN}📄 Log guardado en: $LOG_FILE${NC}"
    if [ -f "$BACKUP_DIR.tar.gz" ]; then
        echo -e "${GREEN}💾 Respaldo guardado en: $BACKUP_DIR.tar.gz${NC}"
    fi
    echo -e "${GREEN}=============================================================================${NC}"
}

# Ejecutar función principal
main "$@"