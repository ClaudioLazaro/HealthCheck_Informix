#!/bin/bash
################################################################################
# Informix HealthCheck - Main Script
# Version: 2.0.0
# Author: Modernized by Claude Code
# Description: Comprehensive Informix database health monitoring tool
#
# Features:
#   - Multi-version Informix support (11.50, 11.70, 12.10, 14.10)
#   - Modular architecture
#   - Modern HTML5 reports with interactive charts
#   - Flexible configuration via JSON
#   - Multiple notification channels (Email, Slack, Teams)
#   - Historical data tracking
#   - Responsive design for mobile viewing
#
# Usage:
#   ./healthcheck.sh [OPTIONS]
#
# Options:
#   -c, --config FILE     Use custom configuration file
#   -h, --hosts FILE      Use custom hosts file
#   -o, --output DIR      Custom output directory for reports
#   -n, --no-email        Skip email notification
#   -v, --verbose         Enable verbose logging
#   -d, --debug           Enable debug mode
#   --help                Show this help message
#   --version             Show version information
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core libraries
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/version_detect.sh"
source "${SCRIPT_DIR}/modules/collector.sh"
source "${SCRIPT_DIR}/modules/report_generator.sh"
source "${SCRIPT_DIR}/modules/notifier.sh"

################################################################################
# Global Variables
################################################################################

VERSION="2.0.0"
CONFIG_FILE="${SCRIPT_DIR}/config/healthcheck.json"
HOSTS_FILE=""
OUTPUT_DIR=""
SKIP_EMAIL=false
VERBOSE=false
DEBUG=false

################################################################################
# Help and Version Functions
################################################################################

show_help() {
    cat <<EOF
Informix HealthCheck v${VERSION}
Comprehensive Informix database health monitoring tool

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -c, --config FILE     Use custom configuration file
                          Default: config/healthcheck.json

    -h, --hosts FILE      Use custom hosts file
                          Default: Read from config

    -o, --output DIR      Custom output directory for reports
                          Default: reports/

    -n, --no-email        Skip email notification
                          Reports will still be generated

    -v, --verbose         Enable verbose logging
                          Shows detailed progress information

    -d, --debug           Enable debug mode
                          Shows all debug messages and SQL queries

    --help                Show this help message

    --version             Show version information

EXAMPLES:
    # Run with default configuration
    ./healthcheck.sh

    # Use custom configuration
    ./healthcheck.sh --config /path/to/config.json

    # Run without sending emails
    ./healthcheck.sh --no-email

    # Debug mode
    ./healthcheck.sh --debug --verbose

CONFIGURATION:
    Edit config/healthcheck.json to customize:
    - Database connection settings
    - Health check thresholds
    - Email notification settings
    - Report preferences
    - Enabled checks

HOSTS FILE:
    Format: hostname|instance_name|port|description
    Example: prod-db01|informix_prod|9088|Production Server

For more information, see README.md

EOF
    exit 0
}

show_version() {
    cat <<EOF
Informix HealthCheck v${VERSION}

Copyright (c) 2024
License: GNU General Public License v3.0

Features:
  - Multi-version Informix support
  - Modern HTML5 reports with charts
  - Email, Slack, Teams notifications
  - Historical tracking
  - Responsive design

EOF
    exit 0
}

################################################################################
# Argument Parsing
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--hosts)
                HOSTS_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--no-email)
                SKIP_EMAIL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                ;;
            --version)
                show_version
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

################################################################################
# Initialization
################################################################################

initialize() {
    log_info "Initializing Informix HealthCheck v${VERSION}"

    # Set up error handling
    setup_error_handling

    # Validate requirements
    if ! validate_requirements; then
        log_error "System requirements not met"
        exit 1
    fi

    # Validate Informix environment
    if ! validate_informix_env; then
        log_error "Informix environment not properly configured"
        exit 1
    fi

    # Verify configuration file
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        log_info "Please create config/healthcheck.json or specify with --config"
        exit 1
    fi

    # Get hosts file from config if not specified
    if [[ -z "${HOSTS_FILE}" ]]; then
        HOSTS_FILE=$(get_config_value ".database.hosts_file" "config/hosts.conf")
        HOSTS_FILE="${SCRIPT_DIR}/${HOSTS_FILE}"
    fi

    # Verify hosts file
    if [[ ! -f "${HOSTS_FILE}" ]]; then
        log_error "Hosts file not found: ${HOSTS_FILE}"
        log_info "Please create a hosts file or check your configuration"
        exit 1
    fi

    # Set output directory
    if [[ -z "${OUTPUT_DIR}" ]]; then
        OUTPUT_DIR=$(get_config_value ".reports.output_dir" "reports")
        OUTPUT_DIR="${SCRIPT_DIR}/${OUTPUT_DIR}"
    fi

    # Initialize logging
    init_logging

    log_success "Initialization complete"
    log_info "Configuration: ${CONFIG_FILE}"
    log_info "Hosts file: ${HOSTS_FILE}"
    log_info "Output directory: ${OUTPUT_DIR}"
}

################################################################################
# Main Execution Flow
################################################################################

run_health_check() {
    local start_time=$(date +%s)

    log_info "========================================"
    log_info "Starting Informix Health Check"
    log_info "========================================"

    # Initialize collection
    init_collection

    # Collect data from all hosts
    log_info "Step 1/4: Collecting data from Informix instances..."
    if ! collect_from_hosts_file "${HOSTS_FILE}"; then
        log_error "Data collection failed"
        return 1
    fi

    # Save to history
    log_info "Step 2/4: Saving metrics to history..."
    save_to_history

    # Generate report
    log_info "Step 3/4: Generating HTML report..."
    init_report
    local report_file=$(generate_report "$(date +%Y%m%d_%H%M%S)")

    if [[ -z "${report_file}" ]] || [[ ! -f "${report_file}" ]]; then
        log_error "Report generation failed"
        return 1
    fi

    log_success "Report generated: ${report_file}"

    # Send notifications
    if [[ "${SKIP_EMAIL}" == "false" ]]; then
        log_info "Step 4/4: Sending notifications..."
        send_notifications "${report_file}" 0 0
    else
        log_info "Step 4/4: Skipping notifications (--no-email specified)"
    fi

    # Clean up old files
    log_info "Cleaning up old files..."
    cleanup_old_files "${OUTPUT_DIR}" "$(get_config_value '.reports.retention_days' '90')" "*.html"
    cleanup_collections

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "========================================"
    log_success "Health check completed successfully!"
    log_info "Duration: ${duration} seconds"
    log_info "Report: ${report_file}"
    log_info "========================================"

    return 0
}

################################################################################
# Main Entry Point
################################################################################

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Initialize environment
    initialize

    # Run health check
    if run_health_check; then
        log_success "Informix HealthCheck completed successfully"
        exit 0
    else
        log_error "Informix HealthCheck failed"
        exit 1
    fi
}

# Execute main function
main "$@"
