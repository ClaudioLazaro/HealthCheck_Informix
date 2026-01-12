#!/bin/bash
################################################################################
# Informix HealthCheck - Utility Functions Library
# Version: 2.0.0
# Description: Common utility functions for logging, JSON parsing, and helpers
################################################################################

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/healthcheck_$(date +%Y%m%d).log"
CONFIG_FILE="${SCRIPT_DIR}/config/healthcheck.json"

# Color codes for terminal output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

################################################################################
# Logging Functions
################################################################################

# Initialize logging
init_logging() {
    local log_dir="${SCRIPT_DIR}/logs"
    mkdir -p "${log_dir}"

    # Rotate old logs if necessary
    rotate_logs "${log_dir}" 30

    log_info "=========================================="
    log_info "Informix HealthCheck Started"
    log_info "Version: 2.0.0"
    log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="
}

# Rotate logs older than specified days
rotate_logs() {
    local log_dir="$1"
    local retention_days="${2:-30}"

    find "${log_dir}" -name "healthcheck_*.log" -type f -mtime +${retention_days} -delete 2>/dev/null
}

# Log message with timestamp
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

# Log info message
log_info() {
    log_message "INFO" "$@"
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"
}

# Log success message
log_success() {
    log_message "SUCCESS" "$@"
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

# Log warning message
log_warning() {
    log_message "WARNING" "$@"
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

# Log error message
log_error() {
    log_message "ERROR" "$@"
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Log debug message
log_debug() {
    local debug_mode=$(get_config_value ".advanced.debug_mode" "false")
    if [[ "${debug_mode}" == "true" ]]; then
        log_message "DEBUG" "$@"
        echo -e "${COLOR_MAGENTA}[DEBUG]${COLOR_RESET} $*"
    fi
}

################################################################################
# JSON Configuration Functions
################################################################################

# Get value from JSON config using jq
get_config_value() {
    local json_path="$1"
    local default_value="${2:-}"

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "${default_value}"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, using default value"
        echo "${default_value}"
        return 1
    fi

    local value=$(jq -r "${json_path} // \"${default_value}\"" "${CONFIG_FILE}" 2>/dev/null)
    echo "${value}"
}

# Get array from JSON config
get_config_array() {
    local json_path="$1"

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "[]"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "[]"
        return 1
    fi

    jq -r "${json_path} // []" "${CONFIG_FILE}" 2>/dev/null
}

# Check if feature is enabled in config
is_check_enabled() {
    local check_name="$1"
    local enabled=$(get_config_value ".checks.${check_name}.enabled" "true")
    [[ "${enabled}" == "true" ]]
}

################################################################################
# File and Directory Functions
################################################################################

# Create directory if it doesn't exist
ensure_directory() {
    local dir_path="$1"
    if [[ ! -d "${dir_path}" ]]; then
        mkdir -p "${dir_path}" 2>/dev/null || {
            log_error "Failed to create directory: ${dir_path}"
            return 1
        }
    fi
    return 0
}

# Clean old files based on retention policy
cleanup_old_files() {
    local directory="$1"
    local retention_days="${2:-90}"
    local pattern="${3:-*}"

    if [[ ! -d "${directory}" ]]; then
        log_warning "Directory not found for cleanup: ${directory}"
        return 1
    fi

    local count=$(find "${directory}" -name "${pattern}" -type f -mtime +${retention_days} 2>/dev/null | wc -l)

    if [[ ${count} -gt 0 ]]; then
        log_info "Cleaning ${count} old files from ${directory}"
        find "${directory}" -name "${pattern}" -type f -mtime +${retention_days} -delete 2>/dev/null
    fi
}

################################################################################
# Database Connection Functions
################################################################################

# Test database connectivity
test_db_connection() {
    local host="$1"
    local instance="$2"

    log_debug "Testing connection to ${instance}@${host}"

    export INFORMIXSERVER="${instance}"

    local result=$(echo "SELECT FIRST 1 1 FROM systables;" | dbaccess sysmaster 2>&1)

    if echo "${result}" | grep -q "1 row(s) retrieved"; then
        log_debug "Connection successful to ${instance}@${host}"
        return 0
    else
        log_error "Connection failed to ${instance}@${host}: ${result}"
        return 1
    fi
}

# Execute SQL query safely
execute_query() {
    local database="$1"
    local query="$2"
    local output_file="$3"
    local instance="${4:-${INFORMIXSERVER}}"

    export INFORMIXSERVER="${instance}"

    log_debug "Executing query on ${database}@${instance}"

    # Create temp file for query
    local temp_query="/tmp/hc_query_$$.sql"
    echo "${query}" > "${temp_query}"

    # Execute query
    local result=$(dbaccess "${database}" "${temp_query}" 2>&1)
    local exit_code=$?

    # Clean up temp file
    rm -f "${temp_query}"

    if [[ ${exit_code} -eq 0 ]]; then
        echo "${result}" > "${output_file}"
        log_debug "Query executed successfully"
        return 0
    else
        log_error "Query execution failed: ${result}"
        return 1
    fi
}

################################################################################
# Data Processing Functions
################################################################################

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit=0
    local size=${bytes}

    while (( $(echo "${size} >= 1024" | bc -l) )) && (( unit < 5 )); do
        size=$(echo "scale=2; ${size} / 1024" | bc)
        ((unit++))
    done

    echo "${size} ${units[$unit]}"
}

# Calculate percentage
calculate_percentage() {
    local value=$1
    local total=$2

    if [[ ${total} -eq 0 ]]; then
        echo "0"
    else
        echo "scale=2; (${value} * 100) / ${total}" | bc
    fi
}

# Get timestamp in various formats
get_timestamp() {
    local format="${1:-%Y%m%d_%H%M%S}"
    date +"${format}"
}

################################################################################
# Validation Functions
################################################################################

# Validate required commands
validate_requirements() {
    local missing_commands=()
    local required_commands=("dbaccess" "awk" "sed" "grep" "date" "bc")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_commands+=("${cmd}")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    # Check optional but recommended commands
    local optional_commands=("jq" "mailx" "wkhtmltopdf")
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            log_warning "Optional command not found: ${cmd} (some features may be limited)"
        fi
    done

    return 0
}

# Validate Informix environment
validate_informix_env() {
    if [[ -z "${INFORMIXDIR:-}" ]]; then
        log_error "INFORMIXDIR environment variable not set"
        return 1
    fi

    if [[ ! -d "${INFORMIXDIR}" ]]; then
        log_error "INFORMIXDIR directory does not exist: ${INFORMIXDIR}"
        return 1
    fi

    if [[ -z "${INFORMIXSERVER:-}" ]]; then
        log_warning "INFORMIXSERVER environment variable not set"
    fi

    return 0
}

################################################################################
# Error Handling
################################################################################

# Error handler
error_handler() {
    local line_no=$1
    local error_code=$2
    log_error "Error occurred in script at line ${line_no} with exit code ${error_code}"
}

# Set up error trap
setup_error_handling() {
    trap 'error_handler ${LINENO} $?' ERR
}

################################################################################
# Progress Indicator
################################################################################

# Show progress spinner
show_progress() {
    local pid=$1
    local message="${2:-Processing}"
    local spin='-\|/'
    local i=0

    while kill -0 ${pid} 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${message} ${spin:$i:1}"
        sleep 0.1
    done

    printf "\r${message} Done\n"
}

################################################################################
# Export functions
################################################################################

export -f log_info log_success log_warning log_error log_debug
export -f get_config_value get_config_array is_check_enabled
export -f ensure_directory cleanup_old_files
export -f test_db_connection execute_query
export -f bytes_to_human calculate_percentage get_timestamp
export -f validate_requirements validate_informix_env
