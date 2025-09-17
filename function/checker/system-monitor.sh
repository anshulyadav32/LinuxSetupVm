#!/bin/bash

# =============================================================================
# System Monitor - Linux Setup VM
# =============================================================================
# Descripción: Monitorea recursos del sistema y rendimiento
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
LOG_FILE="/var/log/linux-setup-vm/system-monitor-$(date +%Y%m%d_%H%M%S).log"

print_help() {
    cat << EOF
${YELLOW}Uso:${NC} $0 [OPCIONES]

${YELLOW}DESCRIPCIÓN:${NC}
  Monitorea recursos del sistema y muestra información de rendimiento

${YELLOW}OPCIONES:${NC}
  -h, --help              Mostrar esta ayuda
  -c, --continuous        Monitoreo continuo (actualiza cada 5 segundos)
  -i, --interval SECONDS  Intervalo personalizado para monitoreo continuo
  -j, --json              Salida en formato JSON
  -s, --summary           Mostrar solo resumen
  -w, --warnings          Mostrar solo advertencias y alertas
  -l, --log               Guardar resultados en log
  --cpu                   Mostrar solo información de CPU
  --memory                Mostrar solo información de memoria
  --disk                  Mostrar solo información de disco
  --network               Mostrar solo información de red
  --processes             Mostrar procesos que más recursos consumen

${YELLOW}EJEMPLOS:${NC}
  $0                      # Monitoreo básico una vez
  $0 --continuous         # Monitoreo continuo cada 5 segundos
  $0 -i 10 -c             # Monitoreo continuo cada 10 segundos
  $0 --json               # Salida en formato JSON
  $0 --cpu --memory       # Solo información de CPU y memoria
  $0 --warnings           # Solo mostrar alertas

EOF
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$LOG_ENABLED" = "true" ]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Obtener información de CPU
get_cpu_info() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_cores=$(nproc)
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_temp=""
    
    # Intentar obtener temperatura de CPU
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp_raw" ]; then
            cpu_temp=$(echo "scale=1; $temp_raw / 1000" | bc 2>/dev/null)
        fi
    fi
    
    echo "$cpu_usage|$cpu_cores|$load_avg|$cpu_temp"
}

# Obtener información de memoria
get_memory_info() {
    local mem_info=$(free -m)
    local mem_total=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
    local mem_used=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
    local mem_free=$(echo "$mem_info" | grep "Mem:" | awk '{print $4}')
    local mem_available=$(echo "$mem_info" | grep "Mem:" | awk '{print $7}')
    local mem_percent=$(( mem_used * 100 / mem_total ))
    
    local swap_total=$(echo "$mem_info" | grep "Swap:" | awk '{print $2}')
    local swap_used=$(echo "$mem_info" | grep "Swap:" | awk '{print $3}')
    local swap_percent=0
    
    if [ "$swap_total" -gt 0 ]; then
        swap_percent=$(( swap_used * 100 / swap_total ))
    fi
    
    echo "$mem_total|$mem_used|$mem_free|$mem_available|$mem_percent|$swap_total|$swap_used|$swap_percent"
}

# Obtener información de disco
get_disk_info() {
    local disk_info=$(df -h / | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')
    local disk_percent=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    
    # Información de I/O si está disponible
    local disk_reads=""
    local disk_writes=""
    
    if command -v iostat &>/dev/null; then
        local io_info=$(iostat -d 1 2 | tail -n +4 | head -1)
        disk_reads=$(echo "$io_info" | awk '{print $3}')
        disk_writes=$(echo "$io_info" | awk '{print $4}')
    fi
    
    echo "$disk_total|$disk_used|$disk_available|$disk_percent|$disk_reads|$disk_writes"
}

# Obtener información de red
get_network_info() {
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    local active_interfaces=""
    local rx_bytes=0
    local tx_bytes=0
    
    for interface in $interfaces; do
        if ip link show "$interface" | grep -q "state UP"; then
            active_interfaces="$active_interfaces $interface"
            
            if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ]; then
                local rx=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
                rx_bytes=$((rx_bytes + rx))
            fi
            
            if [ -f "/sys/class/net/$interface/statistics/tx_bytes" ]; then
                local tx=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
                tx_bytes=$((tx_bytes + tx))
            fi
        fi
    done
    
    # Convertir bytes a MB
    local rx_mb=$(echo "scale=2; $rx_bytes / 1024 / 1024" | bc 2>/dev/null || echo "0")
    local tx_mb=$(echo "scale=2; $tx_bytes / 1024 / 1024" | bc 2>/dev/null || echo "0")
    
    echo "$active_interfaces|$rx_mb|$tx_mb"
}

# Obtener procesos que más recursos consumen
get_top_processes() {
    local cpu_processes=$(ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print $11":"$3}')
    local mem_processes=$(ps aux --sort=-%mem | head -6 | tail -5 | awk '{print $11":"$4}')
    
    echo "$cpu_processes|$mem_processes"
}

# Determinar estado basado en métricas
get_status() {
    local metric="$1"
    local value="$2"
    local warning_threshold="$3"
    local critical_threshold="$4"
    
    if (( $(echo "$value >= $critical_threshold" | bc -l) )); then
        echo "CRITICAL"
    elif (( $(echo "$value >= $warning_threshold" | bc -l) )); then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# Formatear estado con colores
format_status() {
    case "$1" in
        "OK") echo -e "${GREEN}✅ OK${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  ADVERTENCIA${NC}" ;;
        "CRITICAL") echo -e "${RED}❌ CRÍTICO${NC}" ;;
        *) echo -e "${PURPLE}❓ DESCONOCIDO${NC}" ;;
    esac
}

# Mostrar información de CPU
show_cpu_info() {
    local info=$(get_cpu_info)
    IFS='|' read -r cpu_usage cpu_cores load_avg cpu_temp <<< "$info"
    
    local cpu_status=$(get_status "cpu" "$cpu_usage" "70" "85")
    local load_status=$(get_status "load" "$load_avg" "$cpu_cores" "$(echo "$cpu_cores * 1.5" | bc)")
    
    if [ "$WARNINGS_ONLY" = "true" ] && [ "$cpu_status" = "OK" ] && [ "$load_status" = "OK" ]; then
        return
    fi
    
    echo -e "${CYAN}=== INFORMACIÓN DE CPU ===${NC}"
    echo -e "Uso de CPU: ${cpu_usage}% $(format_status $cpu_status)"
    echo -e "Núcleos: $cpu_cores"
    echo -e "Carga promedio: $load_avg $(format_status $load_status)"
    [ -n "$cpu_temp" ] && echo -e "Temperatura: ${cpu_temp}°C"
    echo
}

# Mostrar información de memoria
show_memory_info() {
    local info=$(get_memory_info)
    IFS='|' read -r mem_total mem_used mem_free mem_available mem_percent swap_total swap_used swap_percent <<< "$info"
    
    local mem_status=$(get_status "memory" "$mem_percent" "70" "85")
    local swap_status=$(get_status "swap" "$swap_percent" "50" "80")
    
    if [ "$WARNINGS_ONLY" = "true" ] && [ "$mem_status" = "OK" ] && [ "$swap_status" = "OK" ]; then
        return
    fi
    
    echo -e "${CYAN}=== INFORMACIÓN DE MEMORIA ===${NC}"
    echo -e "RAM Total: ${mem_total}MB"
    echo -e "RAM Usada: ${mem_used}MB (${mem_percent}%) $(format_status $mem_status)"
    echo -e "RAM Libre: ${mem_free}MB"
    echo -e "RAM Disponible: ${mem_available}MB"
    
    if [ "$swap_total" -gt 0 ]; then
        echo -e "Swap Total: ${swap_total}MB"
        echo -e "Swap Usado: ${swap_used}MB (${swap_percent}%) $(format_status $swap_status)"
    else
        echo -e "Swap: No configurado"
    fi
    echo
}

# Mostrar información de disco
show_disk_info() {
    local info=$(get_disk_info)
    IFS='|' read -r disk_total disk_used disk_available disk_percent disk_reads disk_writes <<< "$info"
    
    local disk_status=$(get_status "disk" "$disk_percent" "80" "90")
    
    if [ "$WARNINGS_ONLY" = "true" ] && [ "$disk_status" = "OK" ]; then
        return
    fi
    
    echo -e "${CYAN}=== INFORMACIÓN DE DISCO ===${NC}"
    echo -e "Espacio Total: $disk_total"
    echo -e "Espacio Usado: $disk_used (${disk_percent}%) $(format_status $disk_status)"
    echo -e "Espacio Disponible: $disk_available"
    
    if [ -n "$disk_reads" ] && [ -n "$disk_writes" ]; then
        echo -e "Lecturas/s: $disk_reads"
        echo -e "Escrituras/s: $disk_writes"
    fi
    echo
}

# Mostrar información de red
show_network_info() {
    local info=$(get_network_info)
    IFS='|' read -r active_interfaces rx_mb tx_mb <<< "$info"
    
    echo -e "${CYAN}=== INFORMACIÓN DE RED ===${NC}"
    echo -e "Interfaces activas:$active_interfaces"
    echo -e "Datos recibidos: ${rx_mb}MB"
    echo -e "Datos enviados: ${tx_mb}MB"
    echo
}

# Mostrar procesos principales
show_processes_info() {
    local info=$(get_top_processes)
    IFS='|' read -r cpu_processes mem_processes <<< "$info"
    
    echo -e "${CYAN}=== PROCESOS PRINCIPALES ===${NC}"
    echo -e "${YELLOW}Top CPU:${NC}"
    echo "$cpu_processes" | tr ' ' '\n' | while read -r process; do
        if [ -n "$process" ]; then
            local name=$(echo "$process" | cut -d':' -f1)
            local usage=$(echo "$process" | cut -d':' -f2)
            echo -e "  $name: ${usage}%"
        fi
    done
    
    echo -e "${YELLOW}Top Memoria:${NC}"
    echo "$mem_processes" | tr ' ' '\n' | while read -r process; do
        if [ -n "$process" ]; then
            local name=$(echo "$process" | cut -d':' -f1)
            local usage=$(echo "$process" | cut -d':' -f2)
            echo -e "  $name: ${usage}%"
        fi
    done
    echo
}

# Mostrar resumen
show_summary() {
    local cpu_info=$(get_cpu_info)
    local mem_info=$(get_memory_info)
    local disk_info=$(get_disk_info)
    
    IFS='|' read -r cpu_usage cpu_cores load_avg cpu_temp <<< "$cpu_info"
    IFS='|' read -r mem_total mem_used mem_free mem_available mem_percent swap_total swap_used swap_percent <<< "$mem_info"
    IFS='|' read -r disk_total disk_used disk_available disk_percent disk_reads disk_writes <<< "$disk_info"
    
    local cpu_status=$(get_status "cpu" "$cpu_usage" "70" "85")
    local mem_status=$(get_status "memory" "$mem_percent" "70" "85")
    local disk_status=$(get_status "disk" "$disk_percent" "80" "90")
    
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${YELLOW}                           RESUMEN DEL SISTEMA${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "CPU: ${cpu_usage}% $(format_status $cpu_status) | Memoria: ${mem_percent}% $(format_status $mem_status) | Disco: ${disk_percent}% $(format_status $disk_status)"
    echo -e "Carga: $load_avg/$cpu_cores | RAM: ${mem_used}MB/${mem_total}MB | Espacio: $disk_used/$disk_total"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Salida JSON
print_json() {
    local cpu_info=$(get_cpu_info)
    local mem_info=$(get_memory_info)
    local disk_info=$(get_disk_info)
    local net_info=$(get_network_info)
    
    IFS='|' read -r cpu_usage cpu_cores load_avg cpu_temp <<< "$cpu_info"
    IFS='|' read -r mem_total mem_used mem_free mem_available mem_percent swap_total swap_used swap_percent <<< "$mem_info"
    IFS='|' read -r disk_total disk_used disk_available disk_percent disk_reads disk_writes <<< "$disk_info"
    IFS='|' read -r active_interfaces rx_mb tx_mb <<< "$net_info"
    
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "cpu": {
    "usage_percent": $cpu_usage,
    "cores": $cpu_cores,
    "load_average": $load_avg,
    "temperature": ${cpu_temp:-null}
  },
  "memory": {
    "total_mb": $mem_total,
    "used_mb": $mem_used,
    "free_mb": $mem_free,
    "available_mb": $mem_available,
    "usage_percent": $mem_percent,
    "swap_total_mb": $swap_total,
    "swap_used_mb": $swap_used,
    "swap_usage_percent": $swap_percent
  },
  "disk": {
    "total": "$disk_total",
    "used": "$disk_used",
    "available": "$disk_available",
    "usage_percent": $disk_percent
  },
  "network": {
    "active_interfaces": "$active_interfaces",
    "rx_mb": $rx_mb,
    "tx_mb": $tx_mb
  }
}
EOF
}

# Función principal
main() {
    local continuous=false
    local interval=5
    local json_output=false
    local summary_only=false
    local show_cpu=false
    local show_memory=false
    local show_disk=false
    local show_network=false
    local show_processes=false
    local show_all=true
    
    WARNINGS_ONLY=false
    LOG_ENABLED=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help
                exit 0
                ;;
            -c|--continuous)
                continuous=true
                shift
                ;;
            -i|--interval)
                interval="$2"
                shift 2
                ;;
            -j|--json)
                json_output=true
                shift
                ;;
            -s|--summary)
                summary_only=true
                shift
                ;;
            -w|--warnings)
                WARNINGS_ONLY=true
                shift
                ;;
            -l|--log)
                LOG_ENABLED=true
                shift
                ;;
            --cpu)
                show_cpu=true
                show_all=false
                shift
                ;;
            --memory)
                show_memory=true
                show_all=false
                shift
                ;;
            --disk)
                show_disk=true
                show_all=false
                shift
                ;;
            --network)
                show_network=true
                show_all=false
                shift
                ;;
            --processes)
                show_processes=true
                show_all=false
                shift
                ;;
            -*)
                echo -e "${RED}Error: Opción desconocida: $1${NC}" >&2
                exit 1
                ;;
            *)
                echo -e "${RED}Error: Argumento no reconocido: $1${NC}" >&2
                exit 1
                ;;
        esac
    done
    
    # Función para mostrar información
    show_info() {
        if [ "$json_output" = "true" ]; then
            print_json
        elif [ "$summary_only" = "true" ]; then
            show_summary
        else
            echo -e "${BLUE}=============================================================================${NC}"
            echo -e "${YELLOW}                    MONITOR DEL SISTEMA - $(date)${NC}"
            echo -e "${BLUE}=============================================================================${NC}"
            
            if [ "$show_all" = "true" ]; then
                show_cpu_info
                show_memory_info
                show_disk_info
                show_network_info
                show_processes_info
            else
                [ "$show_cpu" = "true" ] && show_cpu_info
                [ "$show_memory" = "true" ] && show_memory_info
                [ "$show_disk" = "true" ] && show_disk_info
                [ "$show_network" = "true" ] && show_network_info
                [ "$show_processes" = "true" ] && show_processes_info
            fi
        fi
    }
    
    # Mostrar información
    if [ "$continuous" = "true" ]; then
        echo -e "${YELLOW}Monitoreo continuo iniciado (Ctrl+C para detener)${NC}"
        echo -e "${BLUE}Intervalo: ${interval} segundos${NC}"
        echo
        
        while true; do
            clear
            show_info
            sleep "$interval"
        done
    else
        show_info
    fi
}

# Ejecutar función principal
main "$@"