#!/bin/bash

# =============================================================================
# Script de Desinstalación Node.js - Linux Setup VM
# =============================================================================
# Descripción: Desinstala completamente Node.js, npm, yarn y todos los paquetes globales
# =============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/linux-setup-vm/uninstall-nodejs-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/nodejs-backup-$(date +%Y%m%d_%H%M%S)"

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
    echo -e "${YELLOW}                    DESINSTALACIÓN NODE.JS${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Detectar versiones de Node.js
detect_nodejs_versions() {
    local versions=()
    
    # Node.js principal
    if command -v node &> /dev/null; then
        local version=$(node --version 2>/dev/null)
        versions+=("node:$version")
    fi
    
    # Versiones específicas
    for version in 14 16 18 20 21 22; do
        if command -v "node$version" &> /dev/null; then
            versions+=("node$version")
        fi
    done
    
    printf '%s\n' "${versions[@]}"
}

# Detectar paquetes Node.js
detect_nodejs_packages() {
    local packages=()
    
    # Paquetes principales
    for pkg in nodejs npm nodejs-doc; do
        if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            packages+=("$pkg")
        fi
    done
    
    # Versiones específicas
    for version in 14 16 18 20 21 22; do
        for pkg in "nodejs$version" "npm$version"; do
            if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
                packages+=("$pkg")
            fi
        done
    done
    
    printf '%s\n' "${packages[@]}"
}

# Detectar paquetes globales npm
detect_global_packages() {
    local packages=()
    
    if command -v npm &> /dev/null; then
        while IFS= read -r pkg; do
            if [[ -n "$pkg" && "$pkg" != "npm" ]]; then
                packages+=("$pkg")
            fi
        done < <(npm list -g --depth=0 --parseable 2>/dev/null | sed 's/.*node_modules\///' | grep -v '^$')
    fi
    
    printf '%s\n' "${packages[@]}"
}

# Crear backup de configuraciones
backup_configurations() {
    log_message "INFO" "Creando respaldo de configuraciones en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Configuraciones npm globales
    if [ -f "$HOME/.npmrc" ]; then
        cp "$HOME/.npmrc" "$BACKUP_DIR/npmrc" 2>/dev/null
        log_message "INFO" "✅ Respaldo de .npmrc"
    fi
    
    # Lista de paquetes globales
    if command -v npm &> /dev/null; then
        npm list -g --depth=0 > "$BACKUP_DIR/global-packages.txt" 2>/dev/null
        log_message "INFO" "✅ Lista de paquetes globales guardada"
    fi
    
    # Configuraciones de yarn si existe
    if command -v yarn &> /dev/null; then
        yarn global list > "$BACKUP_DIR/yarn-global-packages.txt" 2>/dev/null
        if [ -f "$HOME/.yarnrc" ]; then
            cp "$HOME/.yarnrc" "$BACKUP_DIR/yarnrc" 2>/dev/null
        fi
        log_message "INFO" "✅ Configuraciones de Yarn respaldadas"
    fi
    
    # Comprimir respaldo
    tar -czf "$BACKUP_DIR.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null
    rm -rf "$BACKUP_DIR"
    
    log_message "INFO" "✅ Respaldo comprimido guardado en: $BACKUP_DIR.tar.gz"
}

# Eliminar paquetes globales npm
remove_global_packages() {
    if ! command -v npm &> /dev/null; then
        return 0
    fi
    
    local packages=($(detect_global_packages))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron paquetes globales npm para eliminar"
        return 0
    fi
    
    log_message "INFO" "Eliminando paquetes globales npm..."
    
    echo -e "${YELLOW}Paquetes globales que serán eliminados:${NC}"
    for pkg in "${packages[@]}"; do
        echo -e "${RED}  - $pkg${NC}"
    done
    
    # Eliminar paquetes globales
    for pkg in "${packages[@]}"; do
        log_message "INFO" "Eliminando paquete global: $pkg"
        npm uninstall -g "$pkg" 2>&1 | tee -a "$LOG_FILE"
    done
}

# Eliminar Yarn si está instalado
remove_yarn() {
    if command -v yarn &> /dev/null; then
        log_message "INFO" "Eliminando Yarn..."
        
        # Eliminar paquetes globales de Yarn
        yarn global list --depth=0 2>/dev/null | grep "info " | sed 's/info "\(.*\)@.*/\1/' | while read -r pkg; do
            if [[ -n "$pkg" && "$pkg" != "yarn" ]]; then
                log_message "INFO" "Eliminando paquete global de Yarn: $pkg"
                yarn global remove "$pkg" 2>&1 | tee -a "$LOG_FILE"
            fi
        done
        
        # Eliminar Yarn
        npm uninstall -g yarn 2>&1 | tee -a "$LOG_FILE"
        
        # Eliminar directorios de Yarn
        rm -rf "$HOME/.yarn" "$HOME/.yarnrc" 2>/dev/null
    fi
}

# Eliminar paquetes Node.js del sistema
remove_nodejs_packages() {
    local packages=($(detect_nodejs_packages))
    
    if [ ${#packages[@]} -eq 0 ]; then
        log_message "INFO" "No se encontraron paquetes Node.js para eliminar"
        return 0
    fi
    
    log_message "INFO" "Eliminando paquetes Node.js del sistema..."
    
    echo -e "${YELLOW}Paquetes del sistema que serán eliminados:${NC}"
    for pkg in "${packages[@]}"; do
        echo -e "${RED}  - $pkg${NC}"
    done
    
    # Eliminar paquetes
    sudo apt-get remove --purge -y "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Autoremove
    sudo apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
}

# Eliminar directorios y archivos Node.js
remove_nodejs_files() {
    log_message "INFO" "Eliminando directorios y archivos Node.js..."
    
    # Directorios globales de npm
    local npm_dirs=(
        "/usr/local/lib/node_modules"
        "/usr/local/bin/npm"
        "/usr/local/bin/npx"
        "/usr/local/bin/node"
        "/usr/local/share/man/man1/node.1"
        "/usr/local/share/man/man1/npm.1"
    )
    
    for dir in "${npm_dirs[@]}"; do
        if [ -e "$dir" ]; then
            log_message "INFO" "Eliminando: $dir"
            sudo rm -rf "$dir"
        fi
    done
    
    # Directorios de usuario
    for user_home in /home/* /root; do
        if [ -d "$user_home" ]; then
            local user_dirs=(
                "$user_home/.npm"
                "$user_home/.node_repl_history"
                "$user_home/.npmrc"
                "$user_home/.yarn"
                "$user_home/.yarnrc"
                "$user_home/.config/yarn"
                "$user_home/.cache/yarn"
                "$user_home/node_modules"
            )
            
            for dir in "${user_dirs[@]}"; do
                if [ -e "$dir" ]; then
                    log_message "INFO" "Eliminando directorio de usuario: $dir"
                    rm -rf "$dir"
                fi
            done
        fi
    done
    
    # Limpiar cache de npm
    if command -v npm &> /dev/null; then
        npm cache clean --force 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Limpiar repositorios Node.js
clean_repositories() {
    log_message "INFO" "Limpiando repositorios Node.js..."
    
    # Eliminar claves GPG de NodeSource
    local keys=(
        "68576280"
        "1655A0AB68576280"
        "NodeSource"
    )
    
    for key in "${keys[@]}"; do
        if apt-key list 2>/dev/null | grep -q "$key"; then
            log_message "INFO" "Eliminando clave GPG: $key"
            sudo apt-key del "$key" 2>/dev/null || true
        fi
    done
    
    # Eliminar archivos de repositorio
    local repo_files=(
        "/etc/apt/sources.list.d/nodesource.list"
        "/etc/apt/sources.list.d/nodejs.list"
        "/etc/apt/keyrings/nodesource.gpg"
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

# Verificar desinstalación
verify_removal() {
    log_message "INFO" "Verificando desinstalación..."
    
    local issues=0
    
    # Verificar comandos
    for cmd in node npm npx yarn; do
        if command -v "$cmd" &> /dev/null; then
            log_message "WARN" "⚠️  Comando aún disponible: $cmd"
            ((issues++))
        fi
    done
    
    # Verificar directorios
    for dir in "/usr/local/lib/node_modules" "/usr/local/bin/node"; do
        if [ -e "$dir" ]; then
            log_message "WARN" "⚠️  Directorio/archivo aún existe: $dir"
            ((issues++))
        fi
    done
    
    # Verificar paquetes
    local remaining_packages=($(detect_nodejs_packages))
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
    
    # Verificar si Node.js está instalado
    if ! command -v node &> /dev/null && [ ${#$(detect_nodejs_packages)} -eq 0 ]; then
        log_message "INFO" "Node.js no está instalado en el sistema"
        exit 0
    fi
    
    log_message "INFO" "Iniciando desinstalación de Node.js..."
    
    # Mostrar componentes detectados
    echo -e "${YELLOW}Componentes Node.js detectados:${NC}"
    
    local versions=($(detect_nodejs_versions))
    if [ ${#versions[@]} -gt 0 ]; then
        echo -e "${BLUE}Versiones: ${versions[*]}${NC}"
    fi
    
    local packages=($(detect_nodejs_packages))
    if [ ${#packages[@]} -gt 0 ]; then
        echo -e "${BLUE}Paquetes del sistema: ${#packages[@]} paquetes${NC}"
    fi
    
    local global_packages=($(detect_global_packages))
    if [ ${#global_packages[@]} -gt 0 ]; then
        echo -e "${BLUE}Paquetes globales npm: ${#global_packages[@]} paquetes${NC}"
    fi
    
    if command -v yarn &> /dev/null; then
        echo -e "${BLUE}Yarn: Instalado${NC}"
    fi
    
    echo
    
    # Confirmación
    echo -e "${YELLOW}¿Desea continuar con la desinstalación completa de Node.js? (s/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        log_message "INFO" "Desinstalación cancelada por el usuario"
        exit 0
    fi
    
    # Proceso de desinstalación
    backup_configurations
    remove_global_packages
    remove_yarn
    remove_nodejs_packages
    remove_nodejs_files
    clean_repositories
    verify_removal
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}✅ Desinstalación de Node.js completada${NC}"
    echo -e "${GREEN}📄 Log guardado en: $LOG_FILE${NC}"
    if [ -f "$BACKUP_DIR.tar.gz" ]; then
        echo -e "${GREEN}💾 Respaldo guardado en: $BACKUP_DIR.tar.gz${NC}"
    fi
    echo -e "${GREEN}=============================================================================${NC}"
}

# Ejecutar función principal
main "$@"