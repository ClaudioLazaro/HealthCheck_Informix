#!/bin/bash
################################################################################
# Informix HealthCheck - Version Detection Module
# Version: 2.0.0
# Description: Detect Informix version and adapt queries accordingly
################################################################################

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

# Global version cache
declare -gA INFORMIX_VERSION_CACHE

################################################################################
# Version Detection Functions
################################################################################

# Get Informix version
get_informix_version() {
    local instance="${1:-${INFORMIXSERVER}}"

    # Check cache first
    if [[ -n "${INFORMIX_VERSION_CACHE[${instance}]}" ]]; then
        echo "${INFORMIX_VERSION_CACHE[${instance}]}"
        return 0
    fi

    export INFORMIXSERVER="${instance}"

    log_debug "Detecting Informix version for ${instance}"

    # Query version from sysmaster
    local version_query="SELECT FIRST 1 version FROM sysmasterdatabase:informix.sysmaster:sysversions;"

    local version_output=$(echo "${version_query}" | dbaccess sysmaster 2>&1 | grep -E "IBM Informix|Version" | head -1)

    if [[ -z "${version_output}" ]]; then
        log_warning "Could not detect version for ${instance}, trying alternative method"
        version_output=$(onstat -V 2>/dev/null | grep "Version" | head -1)
    fi

    # Parse version number
    local version=""
    if echo "${version_output}" | grep -qE "[0-9]+\.[0-9]+"; then
        version=$(echo "${version_output}" | grep -oE "[0-9]+\.[0-9]+" | head -1)
    fi

    if [[ -z "${version}" ]]; then
        log_error "Failed to detect Informix version for ${instance}"
        version="unknown"
    else
        log_info "Detected Informix version ${version} for ${instance}"
    fi

    # Cache the version
    INFORMIX_VERSION_CACHE[${instance}]="${version}"

    echo "${version}"
}

# Compare versions (returns 0 if v1 >= v2, 1 otherwise)
version_compare() {
    local v1="$1"
    local v2="$2"

    # Convert versions to comparable format
    local v1_major=$(echo "${v1}" | cut -d. -f1)
    local v1_minor=$(echo "${v1}" | cut -d. -f2)
    local v2_major=$(echo "${v2}" | cut -d. -f1)
    local v2_minor=$(echo "${v2}" | cut -d. -f2)

    # Compare major version
    if [[ ${v1_major} -gt ${v2_major} ]]; then
        return 0
    elif [[ ${v1_major} -lt ${v2_major} ]]; then
        return 1
    fi

    # Compare minor version
    if [[ ${v1_minor} -ge ${v2_minor} ]]; then
        return 0
    else
        return 1
    fi
}

# Check if feature is supported in current version
is_feature_supported() {
    local feature="$1"
    local instance="${2:-${INFORMIXSERVER}}"

    local version=$(get_informix_version "${instance}")

    case "${feature}" in
        "bar_backup")
            # BAR (Backup and Restore) available since 9.x
            version_compare "${version}" "9.0"
            ;;
        "sysadmin")
            # sysadmin database available since 11.50
            version_compare "${version}" "11.50"
            ;;
        "ph_alert")
            # ph_alert table available since 11.50
            version_compare "${version}" "11.50"
            ;;
        "json_support")
            # JSON support available since 12.10
            version_compare "${version}" "12.10"
            ;;
        "timeseries")
            # TimeSeries support available since 12.10
            version_compare "${version}" "12.10"
            ;;
        "mongodb_api")
            # MongoDB wire listener available since 11.70
            version_compare "${version}" "11.70"
            ;;
        "storage_optimization")
            # Storage optimization features since 12.10
            version_compare "${version}" "12.10"
            ;;
        *)
            log_warning "Unknown feature: ${feature}"
            return 1
            ;;
    esac
}

################################################################################
# Query Adaptation Functions
################################################################################

# Get adapted backup query based on version
get_backup_query() {
    local instance="${1:-${INFORMIXSERVER}}"
    local version=$(get_informix_version "${instance}")

    if is_feature_supported "bar_backup" "${instance}"; then
        cat <<'EOF'
SET ISOLATION TO DIRTY READ;
SET LOCK MODE TO WAIT;

UNLOAD TO BACKUP_COLLECT
SELECT
    obj.name AS backup_name,
    EXTEND(act.start_time, YEAR TO SECOND) AS start_time,
    EXTEND(act.end_time, YEAR TO SECOND) AS end_time,
    CASE
        WHEN act.start_time < (TODAY - 1) THEN 'Critical'
        WHEN act.start_time < (TODAY) THEN 'Warning'
        ELSE 'OK'
    END AS health_status,
    (act.end_time - act.start_time) AS duration,
    act.code AS status_code,
    act.msg AS status_message
FROM sysutils:bar_object obj
JOIN sysutils:bar_action act ON obj.id = act.object
WHERE act.code IN (1, 2)
ORDER BY act.start_time DESC;
EOF
    else
        log_warning "BAR backup not supported in version ${version}, using alternative"
        cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO BACKUP_COLLECT
SELECT
    'N/A' AS backup_name,
    'N/A' AS start_time,
    'N/A' AS end_time,
    'Unknown' AS health_status,
    'N/A' AS duration,
    'N/A' AS status_code,
    'BAR not available in this version' AS status_message
FROM systables WHERE tabid = 1;
EOF
    fi
}

# Get adapted dbspace query based on version
get_dbspace_query() {
    local instance="${1:-${INFORMIXSERVER}}"

    cat <<'EOF'
SET ISOLATION TO DIRTY READ;
SET LOCK MODE TO WAIT;

UNLOAD TO DBSPACE_COLLECT
SELECT
    dbs.dbsnum,
    TRIM(dbs.name) AS dbspace_name,
    dbs.is_temp AS is_temp,
    SUM(chk.chksize) AS total_pages,
    SUM(chk.nfree) AS free_pages,
    (SUM(chk.chksize) * (SELECT sh_pagesize FROM sysmaster:sysconfig WHERE cf_name = 'PAGESIZE')) / (1024*1024*1024) AS allocated_gb,
    (SUM(chk.nfree) * (SELECT sh_pagesize FROM sysmaster:sysconfig WHERE cf_name = 'PAGESIZE')) / (1024*1024*1024) AS free_gb,
    CASE
        WHEN (SUM(chk.nfree) * (SELECT sh_pagesize FROM sysmaster:sysconfig WHERE cf_name = 'PAGESIZE')) / (1024*1024*1024) <= 10 THEN 'Critical'
        WHEN (SUM(chk.nfree) * (SELECT sh_pagesize FROM sysmaster:sysconfig WHERE cf_name = 'PAGESIZE')) / (1024*1024*1024) <= 20 THEN 'Warning'
        ELSE 'OK'
    END AS health_status,
    (SUM(chk.nfree) * 100.0 / NULLIF(SUM(chk.chksize), 0)) AS percent_free
FROM sysmaster:sysdbspaces dbs
JOIN sysmaster:syschunks chk ON dbs.dbsnum = chk.dbsnum
WHERE dbs.is_temp = 0
  AND dbs.name NOT IN ('rootdbs', 'llogdbs', 'plogdbs', 'sbspace')
GROUP BY dbs.dbsnum, dbs.name, dbs.is_temp
HAVING (SUM(chk.nfree) * (SELECT sh_pagesize FROM sysmaster:sysconfig WHERE cf_name = 'PAGESIZE')) / (1024*1024*1024) < 50
ORDER BY free_gb ASC;
EOF
}

# Get adapted page usage query based on version
get_pageused_query() {
    local instance="${1:-${INFORMIXSERVER}}"

    cat <<'EOF'
SET ISOLATION TO DIRTY READ;
SET LOCK MODE TO WAIT;

UNLOAD TO PAGEUSED_COLLECT
SELECT FIRST 20
    TRIM(h.dbsname) AS database_name,
    TRIM(h.tabname) AS table_name,
    h.partnum,
    h.nptotal AS pages_allocated,
    h.npused AS pages_used,
    CASE
        WHEN h.npused > 13421772 THEN 'Critical'
        WHEN h.npused > 10000000 THEN 'Warning'
        ELSE 'OK'
    END AS health_status,
    h.npdata AS data_pages,
    (h.nptotal - h.npused) AS free_pages,
    (SELECT sh_pagesize FROM sysmaster:sysconfig WHERE cf_name = 'PAGESIZE') AS page_size,
    ((h.npused * 100.0) / NULLIF(h.nptotal, 0)) AS percent_used
FROM sysmaster:systabnames n
JOIN sysmaster:sysptnhdr h ON n.partnum = h.partnum
WHERE h.npused > 1000000
ORDER BY h.npused DESC;
EOF
}

# Get adapted alerts query based on version
get_alerts_query() {
    local instance="${1:-${INFORMIXSERVER}}"

    if is_feature_supported "ph_alert" "${instance}"; then
        cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO ALERT_COLLECT
SELECT
    TRIM(alert_type) AS alert_type,
    alert_time,
    alert_id,
    TRIM(alert_state) AS alert_state,
    SUBSTR(alert_message, 1, 200) AS alert_message
FROM sysadmin:ph_alert
WHERE alert_time >= TODAY
  AND alert_type NOT IN ('INFO')
ORDER BY alert_time DESC;
EOF
    else
        log_warning "ph_alert not supported, using alternative method"
        cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO ALERT_COLLECT
SELECT
    'SYSTEM' AS alert_type,
    CURRENT AS alert_time,
    0 AS alert_id,
    'N/A' AS alert_state,
    'Alert system not available in this version' AS alert_message
FROM systables WHERE tabid = 1;
EOF
    fi
}

# Get sessions query
get_sessions_query() {
    cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO SESSIONS_COLLECT
SELECT
    sid,
    TRIM(username) AS username,
    TRIM(hostname) AS hostname,
    pid,
    connected,
    CURRENT - connected AS session_duration,
    CASE
        WHEN (CURRENT - connected) UNITS MINUTE > 60 THEN 'Warning'
        ELSE 'OK'
    END AS health_status,
    TRIM(feprogram) AS program
FROM sysmaster:syssessions
WHERE sid > 0
ORDER BY connected ASC;
EOF
}

# Get locks query
get_locks_query() {
    cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO LOCKS_COLLECT
SELECT
    l.owner AS session_id,
    TRIM(s.username) AS username,
    TRIM(d.name) AS database_name,
    TRIM(t.tabname) AS table_name,
    TRIM(l.type) AS lock_type,
    l.waits AS wait_count,
    CASE
        WHEN l.waits > 0 THEN 'Warning'
        ELSE 'OK'
    END AS health_status
FROM sysmaster:syslocks l
LEFT JOIN sysmaster:syssessions s ON l.owner = s.sid
LEFT JOIN sysmaster:sysdatabases d ON l.dbsname = d.name
LEFT JOIN sysmaster:systabnames t ON l.tabname = t.tabname
WHERE l.waits > 0
ORDER BY l.waits DESC;
EOF
}

# Get checkpoints query
get_checkpoints_query() {
    cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO CHECKPOINTS_COLLECT
SELECT
    cp_time,
    n_dirty_buffs AS dirty_buffers,
    time_taken,
    CASE
        WHEN time_taken > 300 THEN 'Warning'
        ELSE 'OK'
    END AS health_status
FROM sysmaster:syscheckpoint
ORDER BY cp_time DESC;
EOF
}

# Get logical logs query
get_logs_query() {
    cat <<'EOF'
SET ISOLATION TO DIRTY READ;

UNLOAD TO LOGS_COLLECT
SELECT
    number AS log_number,
    TRIM(flags) AS flags,
    uniqid AS unique_id,
    size AS log_size,
    used AS log_used,
    CASE
        WHEN flags MATCHES '*B*' AND flags NOT MATCHES '*F*' THEN 'Backed Up'
        WHEN flags MATCHES '*C*' THEN 'Current'
        WHEN flags MATCHES '*F*' THEN 'Free'
        WHEN flags MATCHES '*U*' THEN 'Used'
        ELSE 'Other'
    END AS log_status,
    CASE
        WHEN (SELECT COUNT(*) FROM sysmaster:syslogs WHERE flags MATCHES '*F*') < 5 THEN 'Warning'
        ELSE 'OK'
    END AS health_status
FROM sysmaster:syslogs
ORDER BY number;
EOF
}

################################################################################
# Export functions
################################################################################

export -f get_informix_version version_compare is_feature_supported
export -f get_backup_query get_dbspace_query get_pageused_query
export -f get_alerts_query get_sessions_query get_locks_query
export -f get_checkpoints_query get_logs_query
