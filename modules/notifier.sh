#!/bin/bash
################################################################################
# Informix HealthCheck - Notification Module
# Version: 2.0.0
# Description: Send notifications via email, Slack, Teams, etc.
################################################################################

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

################################################################################
# Email Notification Functions
################################################################################

# Send email with HTML report
send_email_report() {
    local report_file="$1"
    local subject="${2:-Informix HealthCheck Report}"

    # Check if email is enabled
    local email_enabled=$(get_config_value ".email.enabled" "true")
    if [[ "${email_enabled}" != "true" ]]; then
        log_info "Email notification is disabled"
        return 0
    fi

    log_info "Sending email report: ${report_file}"

    # Get email configuration
    local smtp_server=$(get_config_value ".email.smtp_server" "")
    local smtp_port=$(get_config_value ".email.smtp_port" "587")
    local use_tls=$(get_config_value ".email.use_tls" "true")
    local auth_user=$(get_config_value ".email.auth_user" "")
    local auth_password_env=$(get_config_value ".email.auth_password_env" "HEALTHCHECK_SMTP_PASSWORD")
    local from=$(get_config_value ".email.from" "informix@localhost")
    local subject_template=$(get_config_value ".email.subject" "Informix HealthCheck Report - %DATE%")

    # Get recipients
    local to_addresses=$(get_config_value ".email.to[0]" "")
    local cc_addresses=$(get_config_value ".email.cc[0]" "")

    # Validate configuration
    if [[ -z "${smtp_server}" ]] || [[ -z "${to_addresses}" ]]; then
        log_error "Email configuration incomplete"
        return 1
    fi

    # Get password from environment
    local auth_password="${!auth_password_env}"
    if [[ -z "${auth_password}" ]] && [[ -n "${auth_user}" ]]; then
        log_warning "SMTP authentication password not set in environment variable: ${auth_password_env}"
    fi

    # Replace date placeholder in subject
    subject="${subject_template//%DATE%/$(date +%Y-%m-%d)}"

    # Check if mailx is available
    if command -v mailx &> /dev/null; then
        send_via_mailx "${report_file}" "${subject}" "${from}" "${to_addresses}" "${smtp_server}" "${smtp_port}" "${auth_user}" "${auth_password}"
    elif command -v sendmail &> /dev/null; then
        send_via_sendmail "${report_file}" "${subject}" "${from}" "${to_addresses}"
    else
        log_error "No mail command available (mailx or sendmail required)"
        return 1
    fi
}

# Send email using mailx
send_via_mailx() {
    local report_file="$1"
    local subject="$2"
    local from="$3"
    local to="$4"
    local smtp_server="$5"
    local smtp_port="$6"
    local auth_user="$7"
    local auth_password="$8"

    log_debug "Sending email via mailx"

    # Create mailx configuration
    local mailx_config="/tmp/mailx_$$.rc"
    cat > "${mailx_config}" <<EOF
set smtp=${smtp_server}:${smtp_port}
set smtp-use-starttls
set smtp-auth=login
set smtp-auth-user=${auth_user}
set smtp-auth-password=${auth_password}
set from=${from}
set ssl-verify=ignore
EOF

    # Send email with HTML content
    if [[ -f "${report_file}" ]]; then
        (
            echo "Content-Type: text/html; charset=UTF-8"
            echo ""
            cat "${report_file}"
        ) | mailx -v -S sendwait -S "mailrc=${mailx_config}" -s "${subject}" "${to}" 2>&1 | head -20

        local exit_code=$?

        # Clean up config file
        rm -f "${mailx_config}"

        if [[ ${exit_code} -eq 0 ]]; then
            log_success "Email sent successfully to ${to}"
            return 0
        else
            log_error "Failed to send email (exit code: ${exit_code})"
            return 1
        fi
    else
        log_error "Report file not found: ${report_file}"
        rm -f "${mailx_config}"
        return 1
    fi
}

# Send email using sendmail
send_via_sendmail() {
    local report_file="$1"
    local subject="$2"
    local from="$3"
    local to="$4"

    log_debug "Sending email via sendmail"

    if [[ ! -f "${report_file}" ]]; then
        log_error "Report file not found: ${report_file}"
        return 1
    fi

    # Create email with headers
    (
        echo "From: ${from}"
        echo "To: ${to}"
        echo "Subject: ${subject}"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "MIME-Version: 1.0"
        echo ""
        cat "${report_file}"
    ) | sendmail -t

    if [[ $? -eq 0 ]]; then
        log_success "Email sent successfully to ${to}"
        return 0
    else
        log_error "Failed to send email via sendmail"
        return 1
    fi
}

################################################################################
# Slack Notification Functions
################################################################################

# Send Slack notification
send_slack_notification() {
    local message="$1"
    local webhook_url=$(get_config_value ".notifications.webhook_url" "")
    local slack_enabled=$(get_config_value ".notifications.slack_enabled" "false")

    if [[ "${slack_enabled}" != "true" ]]; then
        log_debug "Slack notifications are disabled"
        return 0
    fi

    if [[ -z "${webhook_url}" ]]; then
        log_warning "Slack webhook URL not configured"
        return 1
    fi

    log_info "Sending Slack notification"

    # Create JSON payload
    local payload=$(cat <<EOF
{
    "text": "Informix HealthCheck Alert",
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🏥 Informix HealthCheck Report"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "${message}"
            }
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "Generated at $(date '+%Y-%m-%d %H:%M:%S')"
                }
            ]
        }
    ]
}
EOF
)

    # Send to Slack
    local response=$(curl -s -X POST -H 'Content-type: application/json' \
        --data "${payload}" \
        "${webhook_url}")

    if [[ "${response}" == "ok" ]]; then
        log_success "Slack notification sent successfully"
        return 0
    else
        log_error "Failed to send Slack notification: ${response}"
        return 1
    fi
}

################################################################################
# Microsoft Teams Notification Functions
################################################################################

# Send Teams notification
send_teams_notification() {
    local message="$1"
    local webhook_url=$(get_config_value ".notifications.webhook_url" "")
    local teams_enabled=$(get_config_value ".notifications.teams_enabled" "false")

    if [[ "${teams_enabled}" != "true" ]]; then
        log_debug "Teams notifications are disabled"
        return 0
    fi

    if [[ -z "${webhook_url}" ]]; then
        log_warning "Teams webhook URL not configured"
        return 1
    fi

    log_info "Sending Teams notification"

    # Create JSON payload for Teams
    local payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": "Informix HealthCheck Report",
    "themeColor": "0078D7",
    "title": "🏥 Informix HealthCheck Report",
    "sections": [
        {
            "activityTitle": "Health Check Completed",
            "activitySubtitle": "$(date '+%Y-%m-%d %H:%M:%S')",
            "text": "${message}"
        }
    ]
}
EOF
)

    # Send to Teams
    local response=$(curl -s -X POST -H 'Content-Type: application/json' \
        --data "${payload}" \
        "${webhook_url}")

    if [[ $? -eq 0 ]]; then
        log_success "Teams notification sent successfully"
        return 0
    else
        log_error "Failed to send Teams notification"
        return 1
    fi
}

################################################################################
# Notification Summary
################################################################################

# Send notifications based on health status
send_notifications() {
    local report_file="$1"
    local critical_count="${2:-0}"
    local warning_count="${3:-0}"

    log_info "Processing notifications..."

    # Determine if we should send notifications
    local send_on_critical_only=$(get_config_value ".email.send_on_critical_only" "false")

    if [[ "${send_on_critical_only}" == "true" ]] && [[ ${critical_count} -eq 0 ]]; then
        log_info "No critical issues found, skipping notification (send_on_critical_only=true)"
        return 0
    fi

    # Send email
    send_email_report "${report_file}"

    # Create summary message for chat notifications
    local status_emoji="✅"
    local status_text="All systems healthy"

    if [[ ${critical_count} -gt 0 ]]; then
        status_emoji="🚨"
        status_text="*${critical_count} critical issue(s)* detected"
    elif [[ ${warning_count} -gt 0 ]]; then
        status_emoji="⚠️"
        status_text="*${warning_count} warning(s)* detected"
    fi

    local summary_message="${status_emoji} ${status_text}

*Critical Issues:* ${critical_count}
*Warnings:* ${warning_count}

Report generated: $(date '+%Y-%m-%d %H:%M:%S')"

    # Send Slack notification
    send_slack_notification "${summary_message}"

    # Send Teams notification
    send_teams_notification "${summary_message}"

    log_success "Notifications processed"
}

################################################################################
# Export functions
################################################################################

export -f send_email_report send_slack_notification send_teams_notification send_notifications
