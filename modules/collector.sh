#!/bin/bash
################################################################################
# Informix HealthCheck - Data Collection Module
# Version: 2.0.0
# Description: Collect health metrics from Informix databases
################################################################################

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/version_detect.sh"

# Global variables for collection
COLLECTION_DIR="${SCRIPT_DIR}/data/collections"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

################################################################################
# Collection Infrastructure
################################################################################

# Initialize collection environment
init_collection() {
    ensure_directory "${COLLECTION_DIR}"
    ensure_directory "${COLLECTION_DIR}/${TIMESTAMP}"

    log_info "Initialized collection environment for ${TIMESTAMP}"
}

# Clean up old collections
cleanup_collections() {
    local retention_days=$(get_config_value ".reports.retention_days" "90")
    cleanup_old_files "${COLLECTION_DIR}" "${retention_days}" "*.dat"
}

################################################################################
# Generic Collection Function
################################################################################

# Generic data collector
collect_data() {
    local check_name="$1"
    local host="$2"
    local instance="$3"
    local query_function="$4"

    log_debug "Collecting ${check_name} data from ${instance}@${host}"

    # Check if this check is enabled
    if ! is_check_enabled "${check_name}"; then
        log_debug "${check_name} check is disabled, skipping"
        return 0
    fi

    # Set environment
    export INFORMIXSERVER="${instance}"

    # Get output file
    local output_file="${COLLECTION_DIR}/${TIMESTAMP}/${check_name}_${instance}.dat"

    # Get query from function
    local query=$($query_function "${instance}")

    # Create temp SQL file
    local temp_sql="/tmp/hc_${check_name}_${instance}_$$.sql"
    echo "${query}" > "${temp_sql}"

    # Execute query
    local database="sysmaster"
    if [[ "${check_name}" == "backup" ]]; then
        database="sysutils"
    elif [[ "${check_name}" == "alerts" ]]; then
        database="sysadmin"
    fi

    log_debug "Executing ${check_name} query on ${database}"

    local result=$(dbaccess "${database}" "${temp_sql}" 2>&1)
    local exit_code=$?

    # Clean up temp file
    rm -f "${temp_sql}"

    # Check for output file
    local data_file="${check_name^^}_COLLECT"
    if [[ -f "${data_file}" ]]; then
        mv "${data_file}" "${output_file}"
        log_success "Collected ${check_name} data from ${instance}@${host}"
        return 0
    else
        log_error "Failed to collect ${check_name} data from ${instance}@${host}: ${result}"
        echo "ERROR|${instance}|${check_name}|${result}" >> "${COLLECTION_DIR}/${TIMESTAMP}/errors.log"
        return 1
    fi
}

################################################################################
# Specific Collection Functions
################################################################################

# Collect backup information
collect_backup() {
    local host="$1"
    local instance="$2"

    collect_data "backup" "${host}" "${instance}" "get_backup_query"
}

# Collect dbspace information
collect_dbspace() {
    local host="$1"
    local instance="$2"

    collect_data "dbspace" "${host}" "${instance}" "get_dbspace_query"
}

# Collect page usage information
collect_pageused() {
    local host="$1"
    local instance="$2"

    collect_data "pageused" "${host}" "${instance}" "get_pageused_query"
}

# Collect alerts information
collect_alerts() {
    local host="$1"
    local instance="$2"

    collect_data "alerts" "${host}" "${instance}" "get_alerts_query"
}

# Collect sessions information
collect_sessions() {
    local host="$1"
    local instance="$2"

    collect_data "sessions" "${host}" "${instance}" "get_sessions_query"
}

# Collect locks information
collect_locks() {
    local host="$1"
    local instance="$2"

    collect_data "locks" "${host}" "${instance}" "get_locks_query"
}

# Collect checkpoints information
collect_checkpoints() {
    local host="$1"
    local instance="$2"

    collect_data "checkpoints" "${host}" "${instance}" "get_checkpoints_query"
}

# Collect logical logs information
collect_logs() {
    local host="$1"
    local instance="$2"

    collect_data "logs" "${host}" "${instance}" "get_logs_query"
}

################################################################################
# Advanced Metrics Collection
################################################################################

# Collect system metrics
collect_system_metrics() {
    local host="$1"
    local instance="$2"

    log_debug "Collecting system metrics from ${instance}@${host}"

    export INFORMIXSERVER="${instance}"

    local output_file="${COLLECTION_DIR}/${TIMESTAMP}/system_${instance}.dat"

    # Collect onstat -g dis (disk I/O)
    onstat -g dis 2>/dev/null > "${output_file}.disk" || log_warning "Failed to get disk stats"

    # Collect onstat -g act (active threads)
    onstat -g act 2>/dev/null > "${output_file}.threads" || log_warning "Failed to get thread stats"

    # Collect onstat -g ath (all threads)
    onstat -g ath 2>/dev/null > "${output_file}.allthreads" || log_warning "Failed to get all threads"

    # Collect onstat -g mem (memory usage)
    onstat -g mem 2>/dev/null > "${output_file}.memory" || log_warning "Failed to get memory stats"

    # Collect onstat -g seg (shared memory segments)
    onstat -g seg 2>/dev/null > "${output_file}.segments" || log_warning "Failed to get segment stats"

    log_success "Collected system metrics from ${instance}@${host}"
}

# Collect performance metrics
collect_performance_metrics() {
    local host="$1"
    local instance="$2"

    log_debug "Collecting performance metrics from ${instance}@${host}"

    export INFORMIXSERVER="${instance}"

    local output_file="${COLLECTION_DIR}/${TIMESTAMP}/performance_${instance}.dat"

    # SQL query for performance metrics
    local perf_query="
SET ISOLATION TO DIRTY READ;

SELECT
    (SELECT value FROM sysmaster:sysprofile WHERE name = 'dskreads') AS disk_reads,
    (SELECT value FROM sysmaster:sysprofile WHERE name = 'dskwrites') AS disk_writes,
    (SELECT value FROM sysmaster:sysprofile WHERE name = 'bufwaits') AS buffer_waits,
    (SELECT value FROM sysmaster:sysprofile WHERE name = 'lokwaits') AS lock_waits,
    (SELECT value FROM sysmaster:sysprofile WHERE name = 'deadlks') AS deadlocks,
    (SELECT value FROM sysmaster:sysprofile WHERE name = 'lktouts') AS lock_timeouts,
    (SELECT COUNT(*) FROM sysmaster:syssessions WHERE sid > 0) AS active_sessions,
    (SELECT COUNT(*) FROM sysmaster:syslocks) AS total_locks
FROM systables WHERE tabid = 1;
"

    echo "${perf_query}" | dbaccess sysmaster 2>&1 > "${output_file}"

    if [[ $? -eq 0 ]]; then
        log_success "Collected performance metrics from ${instance}@${host}"
    else
        log_error "Failed to collect performance metrics from ${instance}@${host}"
    fi
}

################################################################################
# Batch Collection Functions
################################################################################

# Collect all metrics for a host
collect_all_metrics() {
    local host="$1"
    local instance="$2"
    local description="${3:-}"

    log_info "========================================"
    log_info "Collecting metrics from: ${instance}@${host}"
    if [[ -n "${description}" ]]; then
        log_info "Description: ${description}"
    fi
    log_info "========================================"

    # Test connection first
    if ! test_db_connection "${host}" "${instance}"; then
        log_error "Cannot connect to ${instance}@${host}, skipping"
        return 1
    fi

    # Detect version
    local version=$(get_informix_version "${instance}")
    log_info "Informix version: ${version}"

    # Collect all enabled checks
    local checks=("backup" "dbspace" "pageused" "alerts" "sessions" "locks" "checkpoints" "logs")

    for check in "${checks[@]}"; do
        if is_check_enabled "${check}"; then
            collect_${check} "${host}" "${instance}" || log_warning "Failed to collect ${check}"
        fi
    done

    # Collect system and performance metrics
    collect_system_metrics "${host}" "${instance}"
    collect_performance_metrics "${host}" "${instance}"

    log_success "Completed collection from ${instance}@${host}"
}

# Process hosts file and collect from all hosts
collect_from_hosts_file() {
    local hosts_file="$1"

    if [[ ! -f "${hosts_file}" ]]; then
        log_error "Hosts file not found: ${hosts_file}"
        return 1
    fi

    log_info "Reading hosts from: ${hosts_file}"

    local host_count=0
    local success_count=0

    while IFS='|' read -r host instance port description; do
        # Skip comments and empty lines
        [[ "${host}" =~ ^#.*$ ]] && continue
        [[ -z "${host}" ]] && continue

        ((host_count++))

        # Collect metrics
        if collect_all_metrics "${host}" "${instance}" "${description}"; then
            ((success_count++))
        fi

    done < "${hosts_file}"

    log_info "========================================"
    log_info "Collection Summary"
    log_info "Total hosts: ${host_count}"
    log_info "Successful: ${success_count}"
    log_info "Failed: $((host_count - success_count))"
    log_info "========================================"

    # Return success if at least one host succeeded
    [[ ${success_count} -gt 0 ]]
}

################################################################################
# Historical Data Functions
################################################################################

# Save metrics to history
save_to_history() {
    local history_enabled=$(get_config_value ".reports.enable_history" "true")

    if [[ "${history_enabled}" != "true" ]]; then
        log_debug "History saving is disabled"
        return 0
    fi

    local history_dir=$(get_config_value ".reports.history_dir" "data/history")
    history_dir="${SCRIPT_DIR}/${history_dir}"

    ensure_directory "${history_dir}"

    # Create history entry
    local history_file="${history_dir}/metrics_${TIMESTAMP}.json"

    log_info "Saving metrics to history: ${history_file}"

    # Convert collected data to JSON (simplified version)
    {
        echo "{"
        echo "  \"timestamp\": \"${TIMESTAMP}\","
        echo "  \"collection_date\": \"$(date -Iseconds)\","
        echo "  \"data_files\": ["

        local first=true
        for file in "${COLLECTION_DIR}/${TIMESTAMP}"/*.dat; do
            if [[ -f "${file}" ]]; then
                [[ "${first}" == "false" ]] && echo ","
                echo -n "    \"$(basename ${file})\""
                first=false
            fi
        done

        echo ""
        echo "  ]"
        echo "}"
    } > "${history_file}"

    log_success "Saved metrics to history"
}

################################################################################
# Export functions
################################################################################

export -f init_collection cleanup_collections
export -f collect_data collect_all_metrics collect_from_hosts_file
export -f collect_backup collect_dbspace collect_pageused collect_alerts
export -f collect_sessions collect_locks collect_checkpoints collect_logs
export -f save_to_history
