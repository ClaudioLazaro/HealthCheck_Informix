#!/bin/bash
################################################################################
# Informix HealthCheck - Setup Script
# Version: 2.0.0
# Description: Initial setup and configuration
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

################################################################################
# Setup Functions
################################################################################

check_dependencies() {
    print_header "Checking Dependencies"

    local missing_deps=()
    local optional_deps=()

    # Required dependencies
    local required=("bash" "awk" "sed" "grep" "date" "bc" "dbaccess")

    for cmd in "${required[@]}"; do
        if command -v "${cmd}" &> /dev/null; then
            print_success "${cmd} found"
        else
            print_error "${cmd} not found (REQUIRED)"
            missing_deps+=("${cmd}")
        fi
    done

    # Optional dependencies
    local optional=("jq" "mailx" "curl" "wkhtmltopdf")

    for cmd in "${optional[@]}"; do
        if command -v "${cmd}" &> /dev/null; then
            print_success "${cmd} found"
        else
            print_warning "${cmd} not found (optional)"
            optional_deps+=("${cmd}")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo ""
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install missing dependencies:"
        echo "  - Debian/Ubuntu: sudo apt-get install ${missing_deps[*]}"
        echo "  - RHEL/CentOS: sudo yum install ${missing_deps[*]}"
        return 1
    fi

    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        echo ""
        print_warning "Missing optional dependencies: ${optional_deps[*]}"
        print_info "Install them for enhanced features:"
        echo "  - jq: JSON parsing (for better config handling)"
        echo "  - mailx: Email notifications"
        echo "  - curl: Slack/Teams notifications"
        echo "  - wkhtmltopdf: PDF export"
    fi

    return 0
}

check_informix_env() {
    print_header "Checking Informix Environment"

    if [[ -z "${INFORMIXDIR:-}" ]]; then
        print_error "INFORMIXDIR not set"
        print_info "Please set INFORMIXDIR environment variable"
        return 1
    else
        print_success "INFORMIXDIR: ${INFORMIXDIR}"
    fi

    if [[ ! -d "${INFORMIXDIR}" ]]; then
        print_error "INFORMIXDIR directory does not exist: ${INFORMIXDIR}"
        return 1
    fi

    if [[ -n "${INFORMIXSERVER:-}" ]]; then
        print_success "INFORMIXSERVER: ${INFORMIXSERVER}"
    else
        print_warning "INFORMIXSERVER not set (can be configured per-host)"
    fi

    # Check if dbaccess works
    if command -v dbaccess &> /dev/null; then
        print_success "dbaccess command available"
    else
        print_error "dbaccess command not found"
        print_info "Make sure Informix bin directory is in PATH"
        return 1
    fi

    return 0
}

create_directory_structure() {
    print_header "Creating Directory Structure"

    local dirs=(
        "config"
        "lib"
        "modules"
        "templates"
        "reports"
        "logs"
        "data/collections"
        "data/history"
    )

    for dir in "${dirs[@]}"; do
        local full_path="${SCRIPT_DIR}/${dir}"
        if [[ -d "${full_path}" ]]; then
            print_success "Directory exists: ${dir}"
        else
            mkdir -p "${full_path}"
            print_success "Created directory: ${dir}"
        fi
    done
}

setup_configuration() {
    print_header "Setting Up Configuration"

    local config_file="${SCRIPT_DIR}/config/healthcheck.json"
    local hosts_file="${SCRIPT_DIR}/config/hosts.conf"

    # Check if config exists
    if [[ -f "${config_file}" ]]; then
        print_warning "Configuration file already exists: ${config_file}"
        read -p "Do you want to backup and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "${config_file}" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
            print_success "Backup created"
        else
            print_info "Keeping existing configuration"
            return 0
        fi
    else
        print_success "Configuration file ready: ${config_file}"
    fi

    # Create hosts file if it doesn't exist
    if [[ ! -f "${hosts_file}" ]]; then
        if [[ -f "${hosts_file}.example" ]]; then
            cp "${hosts_file}.example" "${hosts_file}"
            print_success "Created hosts configuration from example"
            print_warning "Please edit ${hosts_file} with your Informix instances"
        else
            print_error "hosts.conf.example not found"
        fi
    else
        print_success "Hosts file exists: ${hosts_file}"
    fi

    # Configure email settings
    echo ""
    print_info "Configure email notifications:"
    read -p "SMTP Server [smtp.yourdomain.com]: " smtp_server
    smtp_server=${smtp_server:-smtp.yourdomain.com}

    read -p "SMTP Port [587]: " smtp_port
    smtp_port=${smtp_port:-587}

    read -p "From Email [informix@yourdomain.com]: " from_email
    from_email=${from_email:-informix@yourdomain.com}

    read -p "To Email [dba-team@yourdomain.com]: " to_email
    to_email=${to_email:-dba-team@yourdomain.com}

    print_success "Email configuration saved"
    print_warning "Remember to set HEALTHCHECK_SMTP_PASSWORD environment variable"
}

set_permissions() {
    print_header "Setting Permissions"

    # Make scripts executable
    chmod +x "${SCRIPT_DIR}/healthcheck.sh" 2>/dev/null && print_success "healthcheck.sh is executable"
    chmod +x "${SCRIPT_DIR}/setup.sh" 2>/dev/null && print_success "setup.sh is executable"

    # Set permissions on config directory
    chmod 750 "${SCRIPT_DIR}/config" 2>/dev/null && print_success "Config directory permissions set"

    # Set permissions on logs directory
    chmod 750 "${SCRIPT_DIR}/logs" 2>/dev/null && print_success "Logs directory permissions set"
}

setup_cron() {
    print_header "Schedule Automatic Execution (Optional)"

    echo "Would you like to schedule automatic health checks?"
    read -p "Setup cron job? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping cron setup"
        return 0
    fi

    echo ""
    echo "Select schedule:"
    echo "1) Daily at 8:00 AM"
    echo "2) Daily at 6:00 AM"
    echo "3) Every 6 hours"
    echo "4) Custom"
    read -p "Enter choice [1-4]: " schedule_choice

    local cron_schedule=""
    case ${schedule_choice} in
        1)
            cron_schedule="0 8 * * *"
            ;;
        2)
            cron_schedule="0 6 * * *"
            ;;
        3)
            cron_schedule="0 */6 * * *"
            ;;
        4)
            read -p "Enter cron expression: " cron_schedule
            ;;
        *)
            print_warning "Invalid choice, skipping cron setup"
            return 0
            ;;
    esac

    local cron_entry="${cron_schedule} ${SCRIPT_DIR}/healthcheck.sh >> ${SCRIPT_DIR}/logs/cron.log 2>&1"

    echo ""
    echo "Cron entry to add:"
    echo "${cron_entry}"
    echo ""
    read -p "Add this to crontab? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "${cron_entry}") | crontab -
        print_success "Cron job added"
    else
        print_info "Cron job not added. You can add it manually later."
    fi
}

show_next_steps() {
    print_header "Setup Complete!"

    cat <<EOF

${GREEN}✓ Informix HealthCheck v2.0.0 is ready!${NC}

${BLUE}Next Steps:${NC}

1. Configure your Informix instances:
   ${YELLOW}Edit: ${SCRIPT_DIR}/config/hosts.conf${NC}

2. Review and customize settings:
   ${YELLOW}Edit: ${SCRIPT_DIR}/config/healthcheck.json${NC}

3. Set email password (if using email notifications):
   ${YELLOW}export HEALTHCHECK_SMTP_PASSWORD='your-password'${NC}

4. Test the health check:
   ${YELLOW}${SCRIPT_DIR}/healthcheck.sh --help${NC}
   ${YELLOW}${SCRIPT_DIR}/healthcheck.sh --no-email${NC}

5. View reports:
   ${YELLOW}Open: ${SCRIPT_DIR}/reports/*.html${NC}

${BLUE}Documentation:${NC}
   README.md - Full documentation
   config/healthcheck.json - All configuration options

${BLUE}Support:${NC}
   Report issues at: https://github.com/yourusername/HealthCheck_Informix/issues

${GREEN}Happy monitoring!${NC}

EOF
}

################################################################################
# Main Setup Flow
################################################################################

main() {
    clear
    cat <<'EOF'
   ___       ___                    _
  |_ _|_ _  / __|___ _ _ _ __  (_)_ __
   | || ' \| __/ _ \ '_| '  \| \ \ /
  |___|_||_|_| \___/_| |_|_|_|_/_\_\

  HealthCheck Setup v2.0.0

EOF

    # Run setup steps
    if ! check_dependencies; then
        exit 1
    fi

    if ! check_informix_env; then
        exit 1
    fi

    create_directory_structure
    setup_configuration
    set_permissions
    setup_cron
    show_next_steps

    exit 0
}

# Run main function
main "$@"
