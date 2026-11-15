#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/../health_log.txt"

DISK_THRESHOLD=80
CPU_THRESHOLD=90
MEM_THRESHOLD=85
CRITICAL_THRESHOLD=95
LOG_MAX_SIZE=$((5 * 1024 * 1024))
JSON_OUTPUT=false

usage() {
    cat <<'EOF'
Usage: ./system_health.sh [OPTIONS]

Collect system health information and append timestamped logs.

Options:
  --disk VALUE    Disk usage warning threshold (default: 80%)
  --cpu VALUE     CPU usage warning threshold (default: 90%)
  --mem VALUE     Memory usage warning threshold (default: 85%)
  --json          Output results in JSON format
  --help          Display this help message

Exit codes:
  0  Healthy
  1  Warning
  2  Critical
EOF
}

validate_threshold() {
    local name="$1"
    local value="$2"

    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 100 )); then
        printf 'Invalid %s threshold: %s\n' "$name" "$value" >&2
        exit 1
    fi
}

while (($# > 0)); do
    case "$1" in
        --disk|--cpu|--mem)
            if (($# < 2)); then
                printf 'Missing value for %s\n' "$1" >&2
                exit 1
            fi

            option="$1"
            value="$2"
            validate_threshold "$option" "$value"

            case "$option" in
                --disk) DISK_THRESHOLD="$value" ;;
                --cpu) CPU_THRESHOLD="$value" ;;
                --mem) MEM_THRESHOLD="$value" ;;
            esac

            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

read_cpu_stats() {
    local _cpu user nice system idle iowait irq softirq steal rest

    read -r _cpu user nice system idle iowait irq softirq steal rest < /proc/stat

    CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    CPU_IDLE=$((idle + iowait))
}

read_cpu_stats
PREV_TOTAL=$CPU_TOTAL
PREV_IDLE=$CPU_IDLE

sleep 1

read_cpu_stats
TOTAL_DIFF=$((CPU_TOTAL - PREV_TOTAL))
IDLE_DIFF=$((CPU_IDLE - PREV_IDLE))

CPU_USAGE=0

if (( TOTAL_DIFF > 0 )); then
    CPU_USAGE="$(awk -v total="$TOTAL_DIFF" -v idle="$IDLE_DIFF" \
        'BEGIN { printf "%.2f", (total-idle)*100/total }')"
fi

MEM_TOTAL="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
MEM_AVAILABLE="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"

MEM_USAGE="$(awk -v total="$MEM_TOTAL" -v available="$MEM_AVAILABLE" \
    'BEGIN { printf "%.2f", (total-available)*100/total }')"

LOAD_AVERAGE="$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg)"

declare -a DISK_DATA=()
declare -a PROCESS_DATA=()
declare -a WARNINGS=()

# Collect usage from all mounted filesystems.
while read -r size used available use_percent mountpoint; do
    [[ -z "${mountpoint:-}" ]] && continue

    usage_value="${use_percent%%%}"

    fstype="$(findmnt -n -o FSTYPE --target "$mountpoint" 2>/dev/null || echo unknown)"
    mount_options="$(findmnt -n -o OPTIONS --target "$mountpoint" 2>/dev/null || true)"

    DISK_DATA+=("$fstype|$size|$used|$available|$usage_value|$mountpoint")

    if [[ ",${mount_options}," == *,rw,* ]] &&
       (( usage_value > DISK_THRESHOLD )); then
        WARNINGS+=("Disk usage on $mountpoint is ${usage_value}% (threshold: ${DISK_THRESHOLD}%)")
    fi
done < <(df -h --output=size,used,avail,pcent,target | tail -n +2)

# Collect top 5 processes by memory usage.
while read -r pid command memory; do
    PROCESS_DATA+=("$pid|$command|$memory")
done < <(ps -eo pid=,comm=,pmem= --sort=-%mem | head -n 5)

# Check CPU and memory thresholds.
if (( $(awk -v value="$CPU_USAGE" -v limit="$CPU_THRESHOLD" \
    'BEGIN {print (value > limit)}') )); then
    WARNINGS+=("CPU usage is ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)")
fi

if (( $(awk -v value="$MEM_USAGE" -v limit="$MEM_THRESHOLD" \
    'BEGIN {print (value > limit)}') )); then
    WARNINGS+=("Memory usage is ${MEM_USAGE}% (threshold: ${MEM_THRESHOLD}%)")
fi

STATUS="Healthy"
EXIT_CODE=0

if ((${#WARNINGS[@]} > 0)); then
    STATUS="Warning"
    EXIT_CODE=1
fi

# Critical status when CPU, memory or writable disk reaches 95%.
if (( $(awk -v value="$CPU_USAGE" -v limit="$CRITICAL_THRESHOLD" \
    'BEGIN {print (value >= limit)}') )) ||
   (( $(awk -v value="$MEM_USAGE" -v limit="$CRITICAL_THRESHOLD" \
    'BEGIN {print (value >= limit)}') )); then
    STATUS="Critical"
    EXIT_CODE=2
fi

for disk in "${DISK_DATA[@]}"; do
    IFS='|' read -r fstype size used available usage mountpoint <<< "$disk"

    mount_options="$(findmnt -n -o OPTIONS --target "$mountpoint" 2>/dev/null || true)"

    if [[ ",${mount_options}," == *,rw,* ]] &&
       (( usage >= CRITICAL_THRESHOLD )); then
        STATUS="Critical"
        EXIT_CODE=2
    fi
done

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "$(dirname "$LOG_FILE")"

# Rotate the log when it reaches 5 MB.
rotate_log() {
    if [[ -f "$LOG_FILE" ]] &&
       (( $(stat -c '%s' "$LOG_FILE") >= LOG_MAX_SIZE )); then
        mv -f "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

rotate_log

if [[ "$JSON_OUTPUT" == true ]]; then
    {
        printf '{\n'
        printf '  "timestamp": "%s",\n' "$(json_escape "$TIMESTAMP")"
        printf '  "status": "%s",\n' "$STATUS"
        printf '  "cpu_usage_percent": %s,\n' "$CPU_USAGE"
        printf '  "memory_usage_percent": %s,\n' "$MEM_USAGE"
        printf '  "load_average": "%s",\n' "$(json_escape "$LOAD_AVERAGE")"
        printf '  "disks": [\n'

        for i in "${!DISK_DATA[@]}"; do
            IFS='|' read -r fstype size used available usage mountpoint <<< "${DISK_DATA[$i]}"

            printf '    {"type":"%s","size":"%s","used":"%s","available":"%s","usage_percent":%s,"mountpoint":"%s"}' \
                "$(json_escape "$fstype")" \
                "$(json_escape "$size")" \
                "$(json_escape "$used")" \
                "$(json_escape "$available")" \
                "$usage" \
                "$(json_escape "$mountpoint")"

            if (( i < ${#DISK_DATA[@]} - 1 )); then
                printf ','
            fi
            printf '\n'
        done

        printf '  ],\n'
        printf '  "top_5_processes": [\n'

        for i in "${!PROCESS_DATA[@]}"; do
            IFS='|' read -r pid command memory <<< "${PROCESS_DATA[$i]}"

            printf '    {"pid":%s,"command":"%s","memory_percent":%s}' \
                "$pid" "$(json_escape "$command")" "$memory"

            if (( i < ${#PROCESS_DATA[@]} - 1 )); then
                printf ','
            fi
            printf '\n'
        done

        printf '  ],\n'
        printf '  "warnings": [\n'

        for i in "${!WARNINGS[@]}"; do
            printf '    "%s"' "$(json_escape "${WARNINGS[$i]}")"

            if (( i < ${#WARNINGS[@]} - 1 )); then
                printf ','
            fi
            printf '\n'
        done

        printf '  ]\n'
        printf '}\n'
    } > "$LOG_FILE.tmp"

    # Append the JSON report to the log and display it.
    cat "$LOG_FILE.tmp" >> "$LOG_FILE"
    cat "$LOG_FILE.tmp"
    rm -f "$LOG_FILE.tmp"
else
    {
        printf '[%s]\n' "$TIMESTAMP"
        printf 'Status: %s\n' "$STATUS"
        printf 'CPU Usage: %s%%\n' "$CPU_USAGE"
        printf 'Memory Usage: %s%%\n' "$MEM_USAGE"
        printf 'Load Average: %s\n' "$LOAD_AVERAGE"

        printf '\nDisk Usage:\n'

        for disk in "${DISK_DATA[@]}"; do
            IFS='|' read -r fstype size used available usage mountpoint <<< "$disk"
            printf '  %s (%s): %s%%\n' "$mountpoint" "$fstype" "$usage"
        done

        printf '\nTop 5 Processes by Memory:\n'

        for process in "${PROCESS_DATA[@]}"; do
            IFS='|' read -r pid command memory <<< "$process"
            printf '  PID: %s | Process: %s | Memory: %s%%\n' "$pid" "$command" "$memory"
        done

        if ((${#WARNINGS[@]} > 0)); then
            printf '\n'
            for warning in "${WARNINGS[@]}"; do
                printf '[WARNING] %s\n' "$warning"
            done
        fi

        printf '\n'
    } | tee -a "$LOG_FILE"
fi

exit "$EXIT_CODE"
