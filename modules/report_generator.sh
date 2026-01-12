#!/bin/bash
################################################################################
# Informix HealthCheck - Report Generator Module
# Version: 2.0.0
# Description: Generate modern HTML reports from collected data
################################################################################

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

# Global variables
REPORT_OUTPUT_DIR="${SCRIPT_DIR}/reports"
TEMPLATE_FILE="${SCRIPT_DIR}/templates/report_template.html"
COLLECTION_DIR="${SCRIPT_DIR}/data/collections"

################################################################################
# Report Generation Infrastructure
################################################################################

# Initialize report generation
init_report() {
    ensure_directory "${REPORT_OUTPUT_DIR}"
    log_info "Initialized report generation"
}

# Generate filename based on pattern
get_report_filename() {
    local pattern=$(get_config_value ".reports.filename_pattern" "HealthCheck_Report_%Y%m%d_%H%M%S.html")
    local filename=$(date +"${pattern}")
    echo "${REPORT_OUTPUT_DIR}/${filename}"
}

################################################################################
# Summary Card Generation
################################################################################

# Generate summary card HTML
generate_summary_card() {
    local title="$1"
    local value="$2"
    local description="$3"
    local status="${4:-info}"
    local icon="${5:-fa-info-circle}"

    cat <<EOF
<div class="summary-card ${status}">
    <div class="summary-card-header">
        <span class="summary-card-title">${title}</span>
        <i class="fas ${icon} summary-card-icon"></i>
    </div>
    <div class="summary-card-value">${value}</div>
    <div class="summary-card-description">${description}</div>
</div>
EOF
}

# Generate all summary cards
generate_summary_cards() {
    local timestamp="$1"
    local collection_path="${COLLECTION_DIR}/${timestamp}"

    log_debug "Generating summary cards from ${collection_path}"

    local total_hosts=0
    local critical_count=0
    local warning_count=0
    local ok_count=0

    # Count files to determine host count
    total_hosts=$(find "${collection_path}" -name "backup_*.dat" -type f 2>/dev/null | wc -l)

    # Analyze backup status
    for backup_file in "${collection_path}"/backup_*.dat; do
        [[ -f "${backup_file}" ]] || continue

        local critical_backups=$(grep -c "Critical" "${backup_file}" 2>/dev/null || echo 0)
        local warning_backups=$(grep -c "Warning" "${backup_file}" 2>/dev/null || echo 0)

        critical_count=$((critical_count + critical_backups))
        warning_count=$((warning_count + warning_backups))
    done

    # Analyze dbspace status
    local critical_dbspaces=0
    local warning_dbspaces=0
    for dbspace_file in "${collection_path}"/dbspace_*.dat; do
        [[ -f "${dbspace_file}" ]] || continue

        local crit=$(grep -c "Critical" "${dbspace_file}" 2>/dev/null || echo 0)
        local warn=$(grep -c "Warning" "${dbspace_file}" 2>/dev/null || echo 0)

        critical_dbspaces=$((critical_dbspaces + crit))
        warning_dbspaces=$((warning_dbspaces + warn))
    done

    # Analyze page usage
    local critical_pages=0
    for page_file in "${collection_path}"/pageused_*.dat; do
        [[ -f "${page_file}" ]] || continue

        local crit=$(grep -c "Critical" "${page_file}" 2>/dev/null || echo 0)
        critical_pages=$((critical_pages + crit))
    done

    # Count alerts
    local total_alerts=0
    for alert_file in "${collection_path}"/alerts_*.dat; do
        [[ -f "${alert_file}" ]] || continue

        local count=$(grep -v "^$" "${alert_file}" 2>/dev/null | wc -l)
        total_alerts=$((total_alerts + count))
    done

    # Determine overall status
    local overall_status="success"
    local overall_icon="fa-check-circle"
    if [[ ${critical_count} -gt 0 ]] || [[ ${critical_dbspaces} -gt 0 ]] || [[ ${critical_pages} -gt 0 ]]; then
        overall_status="critical"
        overall_icon="fa-exclamation-circle"
    elif [[ ${warning_count} -gt 0 ]] || [[ ${warning_dbspaces} -gt 0 ]]; then
        overall_status="warning"
        overall_icon="fa-exclamation-triangle"
    fi

    # Generate cards
    {
        generate_summary_card "Overall Health" "$(echo ${overall_status} | tr '[:lower:]' '[:upper:]')" "System health status" "${overall_status}" "${overall_icon}"
        generate_summary_card "Total Hosts" "${total_hosts}" "Monitored Informix instances" "info" "fa-server"
        generate_summary_card "Critical Issues" "${critical_count}" "Backup and space issues" "$([ ${critical_count} -gt 0 ] && echo 'critical' || echo 'success')" "fa-exclamation-circle"
        generate_summary_card "Warnings" "${warning_count}" "Items requiring attention" "$([ ${warning_count} -gt 0 ] && echo 'warning' || echo 'success')" "fa-exclamation-triangle"
        generate_summary_card "DBSpace Issues" "${critical_dbspaces}" "Critical space problems" "$([ ${critical_dbspaces} -gt 0 ] && echo 'critical' || echo 'success')" "fa-hdd"
        generate_summary_card "Active Alerts" "${total_alerts}" "System alerts today" "$([ ${total_alerts} -gt 0 ] && echo 'warning' || echo 'info')" "fa-bell"
    }
}

################################################################################
# Section Generation
################################################################################

# Generate backup section
generate_backup_section() {
    local timestamp="$1"
    local collection_path="${COLLECTION_DIR}/${timestamp}"

    log_debug "Generating backup section"

    cat <<'EOF'
<div id="backup-section" class="section">
    <div class="section-header">
        <div class="section-title">
            <i class="fas fa-save"></i>
            Backup Status Report
        </div>
    </div>
    <div class="section-body">
        <div class="table-container">
            <table id="backup-table">
                <thead>
                    <tr>
                        <th>Instance</th>
                        <th>Backup Name</th>
                        <th>Start Time</th>
                        <th>End Time</th>
                        <th>Duration</th>
                        <th>Status</th>
                        <th>Health</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Process backup data files
    for backup_file in "${collection_path}"/backup_*.dat; do
        [[ -f "${backup_file}" ]] || continue

        local instance=$(basename "${backup_file}" | sed 's/backup_//;s/.dat//')

        while IFS='|' read -r name start_time end_time health duration status_code status_msg; do
            # Skip empty lines
            [[ -z "${name}" ]] && continue

            # Determine status badge class
            local badge_class="ok"
            [[ "${health}" == "Critical" ]] && badge_class="critical"
            [[ "${health}" == "Warning" ]] && badge_class="warning"

            cat <<EOF
                    <tr>
                        <td><strong>${instance}</strong></td>
                        <td>${name}</td>
                        <td>${start_time}</td>
                        <td>${end_time}</td>
                        <td>${duration}</td>
                        <td>${status_msg}</td>
                        <td><span class="status-badge ${badge_class}"><i class="fas fa-circle"></i> ${health}</span></td>
                    </tr>
EOF
        done < "${backup_file}"
    done

    cat <<'EOF'
                </tbody>
            </table>
        </div>
    </div>
</div>
EOF
}

# Generate dbspace section
generate_dbspace_section() {
    local timestamp="$1"
    local collection_path="${COLLECTION_DIR}/${timestamp}"

    log_debug "Generating dbspace section"

    cat <<'EOF'
<div id="dbspace-section" class="section">
    <div class="section-header">
        <div class="section-title">
            <i class="fas fa-hdd"></i>
            DBSpace Usage Report
        </div>
    </div>
    <div class="section-body">
        <div class="table-container">
            <table id="dbspace-table">
                <thead>
                    <tr>
                        <th>Instance</th>
                        <th>DBSpace #</th>
                        <th>Name</th>
                        <th>Allocated (GB)</th>
                        <th>Free (GB)</th>
                        <th>Free (%)</th>
                        <th>Health</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Process dbspace data files
    for dbspace_file in "${collection_path}"/dbspace_*.dat; do
        [[ -f "${dbspace_file}" ]] || continue

        local instance=$(basename "${dbspace_file}" | sed 's/dbspace_//;s/.dat//')

        while IFS='|' read -r dbsnum name is_temp total_pages free_pages allocated_gb free_gb health percent_free; do
            [[ -z "${dbsnum}" ]] && continue

            local badge_class="ok"
            [[ "${health}" == "Critical" ]] && badge_class="critical"
            [[ "${health}" == "Warning" ]] && badge_class="warning"

            # Format numbers
            allocated_gb=$(printf "%.2f" "${allocated_gb}" 2>/dev/null || echo "${allocated_gb}")
            free_gb=$(printf "%.2f" "${free_gb}" 2>/dev/null || echo "${free_gb}")
            percent_free=$(printf "%.2f" "${percent_free}" 2>/dev/null || echo "${percent_free}")

            cat <<EOF
                    <tr>
                        <td><strong>${instance}</strong></td>
                        <td>${dbsnum}</td>
                        <td>${name}</td>
                        <td>${allocated_gb}</td>
                        <td>${free_gb}</td>
                        <td>${percent_free}%</td>
                        <td><span class="status-badge ${badge_class}"><i class="fas fa-circle"></i> ${health}</span></td>
                    </tr>
EOF
        done < "${dbspace_file}"
    done

    cat <<'EOF'
                </tbody>
            </table>
        </div>
    </div>
</div>
EOF
}

# Generate pages section
generate_pages_section() {
    local timestamp="$1"
    local collection_path="${COLLECTION_DIR}/${timestamp}"

    log_debug "Generating pages section"

    cat <<'EOF'
<div id="pages-section" class="section">
    <div class="section-header">
        <div class="section-title">
            <i class="fas fa-file"></i>
            Table Page Usage Report
        </div>
    </div>
    <div class="section-body">
        <div class="table-container">
            <table id="pages-table">
                <thead>
                    <tr>
                        <th>Instance</th>
                        <th>Database</th>
                        <th>Table</th>
                        <th>Pages Allocated</th>
                        <th>Pages Used</th>
                        <th>% Used</th>
                        <th>Free Pages</th>
                        <th>Health</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Process page usage data files
    for page_file in "${collection_path}"/pageused_*.dat; do
        [[ -f "${page_file}" ]] || continue

        local instance=$(basename "${page_file}" | sed 's/pageused_//;s/.dat//')

        while IFS='|' read -r database table partnum pages_allocated pages_used health data_pages free_pages page_size percent_used; do
            [[ -z "${database}" ]] && continue

            local badge_class="ok"
            [[ "${health}" == "Critical" ]] && badge_class="critical"
            [[ "${health}" == "Warning" ]] && badge_class="warning"

            percent_used=$(printf "%.2f" "${percent_used}" 2>/dev/null || echo "${percent_used}")

            cat <<EOF
                    <tr>
                        <td><strong>${instance}</strong></td>
                        <td>${database}</td>
                        <td>${table}</td>
                        <td>${pages_allocated}</td>
                        <td>${pages_used}</td>
                        <td>${percent_used}%</td>
                        <td>${free_pages}</td>
                        <td><span class="status-badge ${badge_class}"><i class="fas fa-circle"></i> ${health}</span></td>
                    </tr>
EOF
        done < "${page_file}"
    done

    cat <<'EOF'
                </tbody>
            </table>
        </div>
    </div>
</div>
EOF
}

# Generate alerts section
generate_alerts_section() {
    local timestamp="$1"
    local collection_path="${COLLECTION_DIR}/${timestamp}"

    log_debug "Generating alerts section"

    cat <<'EOF'
<div id="alerts-section" class="section">
    <div class="section-header">
        <div class="section-title">
            <i class="fas fa-exclamation-triangle"></i>
            System Alerts & Messages
        </div>
    </div>
    <div class="section-body">
        <div class="table-container">
            <table id="alerts-table">
                <thead>
                    <tr>
                        <th>Instance</th>
                        <th>Alert Type</th>
                        <th>Time</th>
                        <th>Alert ID</th>
                        <th>State</th>
                        <th>Message</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Process alert data files
    for alert_file in "${collection_path}"/alerts_*.dat; do
        [[ -f "${alert_file}" ]] || continue

        local instance=$(basename "${alert_file}" | sed 's/alerts_//;s/.dat//')

        while IFS='|' read -r alert_type alert_time alert_id alert_state alert_message; do
            [[ -z "${alert_type}" ]] && continue

            cat <<EOF
                    <tr>
                        <td><strong>${instance}</strong></td>
                        <td><span class="status-badge warning">${alert_type}</span></td>
                        <td>${alert_time}</td>
                        <td>${alert_id}</td>
                        <td>${alert_state}</td>
                        <td>${alert_message}</td>
                    </tr>
EOF
        done < "${alert_file}"
    done

    cat <<'EOF'
                </tbody>
            </table>
        </div>
    </div>
</div>
EOF
}

# Generate sessions section
generate_sessions_section() {
    local timestamp="$1"
    local collection_path="${COLLECTION_DIR}/${timestamp}"

    log_debug "Generating sessions section"

    cat <<'EOF'
<div id="sessions-section" class="section">
    <div class="section-header">
        <div class="section-title">
            <i class="fas fa-users"></i>
            Active Sessions Report
        </div>
    </div>
    <div class="section-body">
        <div class="table-container">
            <table id="sessions-table">
                <thead>
                    <tr>
                        <th>Instance</th>
                        <th>Session ID</th>
                        <th>Username</th>
                        <th>Hostname</th>
                        <th>Program</th>
                        <th>Duration</th>
                        <th>Health</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Process session data files
    for session_file in "${collection_path}"/sessions_*.dat; do
        [[ -f "${session_file}" ]] || continue

        local instance=$(basename "${session_file}" | sed 's/sessions_//;s/.dat//')

        while IFS='|' read -r sid username hostname pid connected duration health program; do
            [[ -z "${sid}" ]] && continue

            local badge_class="ok"
            [[ "${health}" == "Warning" ]] && badge_class="warning"

            cat <<EOF
                    <tr>
                        <td><strong>${instance}</strong></td>
                        <td>${sid}</td>
                        <td>${username}</td>
                        <td>${hostname}</td>
                        <td>${program}</td>
                        <td>${duration}</td>
                        <td><span class="status-badge ${badge_class}"><i class="fas fa-circle"></i> ${health}</span></td>
                    </tr>
EOF
        done < "${session_file}"
    done

    cat <<'EOF'
                </tbody>
            </table>
        </div>
    </div>
</div>
EOF
}

# Generate overview section with charts
generate_overview_section() {
    local timestamp="$1"

    cat <<'EOF'
<div id="overview-section" class="section active">
    <div class="section-header">
        <div class="section-title">
            <i class="fas fa-chart-pie"></i>
            Health Overview
        </div>
    </div>
    <div class="section-body">
        <div class="chart-container">
            <div class="chart-wrapper">
                <canvas id="healthOverviewChart"></canvas>
            </div>
            <div class="chart-wrapper">
                <canvas id="dbspaceUsageChart"></canvas>
            </div>
        </div>
    </div>
</div>

<script>
// Health Overview Chart
const healthCtx = document.getElementById('healthOverviewChart');
if (healthCtx) {
    new Chart(healthCtx, {
        type: 'doughnut',
        data: {
            labels: ['Critical', 'Warning', 'OK'],
            datasets: [{
                data: [{{CRITICAL_COUNT}}, {{WARNING_COUNT}}, {{OK_COUNT}}],
                backgroundColor: ['#e74c3c', '#f39c12', '#27ae60']
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                title: {
                    display: true,
                    text: 'Overall Health Status',
                    font: { size: 18 }
                },
                legend: {
                    position: 'bottom'
                }
            }
        }
    });
}

// DBSpace Usage Chart (placeholder)
const dbspaceCtx = document.getElementById('dbspaceUsageChart');
if (dbspaceCtx) {
    new Chart(dbspaceCtx, {
        type: 'bar',
        data: {
            labels: ['DBSpace 1', 'DBSpace 2', 'DBSpace 3', 'DBSpace 4'],
            datasets: [{
                label: 'Used Space (GB)',
                data: [50, 75, 30, 90],
                backgroundColor: '#3498db'
            }, {
                label: 'Free Space (GB)',
                data: [50, 25, 70, 10],
                backgroundColor: '#27ae60'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                title: {
                    display: true,
                    text: 'DBSpace Usage Distribution',
                    font: { size: 18 }
                }
            },
            scales: {
                x: { stacked: true },
                y: { stacked: true }
            }
        }
    });
}
</script>
EOF
}

################################################################################
# Main Report Generation
################################################################################

# Generate complete report
generate_report() {
    local timestamp="$1"

    log_info "Generating HTML report for collection: ${timestamp}"

    local output_file=$(get_report_filename)
    local report_date=$(date +"%Y-%m-%d")
    local report_time=$(date +"%H:%M:%S")

    # Read template
    if [[ ! -f "${TEMPLATE_FILE}" ]]; then
        log_error "Template file not found: ${TEMPLATE_FILE}"
        return 1
    fi

    local template_content=$(<"${TEMPLATE_FILE}")

    # Generate components
    local summary_cards=$(generate_summary_cards "${timestamp}")
    local content_sections=""

    content_sections+=$(generate_overview_section "${timestamp}")
    content_sections+=$(generate_backup_section "${timestamp}")
    content_sections+=$(generate_dbspace_section "${timestamp}")
    content_sections+=$(generate_pages_section "${timestamp}")
    content_sections+=$(generate_sessions_section "${timestamp}")
    content_sections+=$(generate_alerts_section "${timestamp}")

    # Count totals for charts
    local collection_path="${COLLECTION_DIR}/${timestamp}"
    local total_hosts=$(find "${collection_path}" -name "backup_*.dat" -type f 2>/dev/null | wc -l)
    local critical_count=10  # Placeholder
    local warning_count=5    # Placeholder
    local ok_count=30        # Placeholder

    # Replace placeholders
    template_content="${template_content//\{\{REPORT_DATE\}\}/${report_date}}"
    template_content="${template_content//\{\{REPORT_TIME\}\}/${report_time}}"
    template_content="${template_content//\{\{TOTAL_HOSTS\}\}/${total_hosts}}"
    template_content="${template_content//\{\{INFORMIX_VERSION\}\}/14.10}"
    template_content="${template_content//\{\{SUMMARY_CARDS\}\}/${summary_cards}}"
    template_content="${template_content//\{\{CONTENT_SECTIONS\}\}/${content_sections}}"
    template_content="${template_content//\{\{CRITICAL_COUNT\}\}/${critical_count}}"
    template_content="${template_content//\{\{WARNING_COUNT\}\}/${warning_count}}"
    template_content="${template_content//\{\{OK_COUNT\}\}/${ok_count}}"

    # Write output
    echo "${template_content}" > "${output_file}"

    log_success "Report generated: ${output_file}"
    echo "${output_file}"
}

################################################################################
# Export functions
################################################################################

export -f init_report generate_report get_report_filename
