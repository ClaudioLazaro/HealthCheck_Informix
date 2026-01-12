# Changelog

All notable changes to the Informix HealthCheck project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-01-15

### 🎉 Major Release - Complete Modernization

This version represents a complete rewrite and modernization of the Informix HealthCheck application.

### ✨ Added

#### Architecture & Code Quality
- **Modular architecture** with separated concerns (lib/, modules/, templates/)
- **Comprehensive logging system** with different log levels (INFO, WARNING, ERROR, DEBUG)
- **Error handling** with proper validation and user-friendly messages
- **Configuration via JSON** (config/healthcheck.json) instead of hardcoded values
- **Setup script** (setup.sh) for guided installation and configuration

#### Multi-Version Support
- **Automatic Informix version detection** (11.50, 11.70, 12.10, 14.10+)
- **Version-specific query adaptation** based on detected version
- **Feature compatibility checking** for version-dependent functionality

#### New Health Checks
- **Active sessions monitoring** with long-running query detection
- **Lock and deadlock monitoring** with detailed lock information
- **Checkpoint performance tracking** with duration alerts
- **Logical log monitoring** with free log alerts
- **System metrics collection** (I/O, memory, threads via onstat)
- **Performance metrics** (buffer waits, lock waits, deadlocks)

#### Modern HTML5 Reports
- **Responsive design** that works on desktop, tablet, and mobile
- **Interactive charts** using Chart.js for data visualization
- **Real-time search and filtering** across all tables
- **Tab-based navigation** between different sections
- **Status badges** with color coding (Critical, Warning, OK)
- **Modern UI** with gradients, shadows, and smooth animations
- **Print-friendly** layout for PDF export
- **Summary dashboard** with key metrics cards

#### Notifications & Integrations
- **Email notifications** with configurable SMTP settings
- **Slack integration** via webhooks with rich message formatting
- **Microsoft Teams integration** via webhooks
- **Conditional notifications** (send only on critical issues option)
- **No hardcoded credentials** - uses environment variables

#### Data Management
- **Historical metrics tracking** for trend analysis
- **Data retention policies** with automatic cleanup
- **Collection timestamp tracking** for audit purposes
- **Structured data storage** in organized directories

#### Usability
- **Command-line options** (--config, --hosts, --no-email, --verbose, --debug)
- **Comprehensive help** (--help flag with examples)
- **Version information** (--version flag)
- **Progress indicators** and status messages
- **Color-coded terminal output** for better readability

### 🔧 Changed

#### Configuration
- Configuration moved from hardcoded values to `config/healthcheck.json`
- Hosts configuration separated into `config/hosts.conf`
- All thresholds now configurable via JSON
- Email credentials via environment variables (HEALTHCHECK_SMTP_PASSWORD)

#### Code Structure
- Split monolithic script into modular components:
  - `lib/utils.sh` - Utility functions and logging
  - `lib/version_detect.sh` - Version detection and query adaptation
  - `modules/collector.sh` - Data collection functions
  - `modules/report_generator.sh` - HTML report generation
  - `modules/notifier.sh` - Notification system
  - `healthcheck.sh` - Main orchestration script

#### Report Generation
- Complete redesign of HTML reports with modern CSS
- Added Chart.js for interactive visualizations
- Improved table formatting and readability
- Added search and filter capabilities
- Mobile-responsive design

#### Data Collection
- More robust error handling during collection
- Parallel data collection support (configurable)
- Better handling of connection failures
- Validation of collected data

### 🐛 Fixed

- SQL injection vulnerabilities (now using prepared queries)
- Hardcoded email credentials security issue
- Typo in "batabase" → "database" (line 153 of old script)
- Inconsistent error handling across functions
- Unsafe temp file cleanup with rm -rf
- Missing validation for environment variables

### 🔒 Security

- **Removed hardcoded credentials** from codebase
- **Environment variable-based authentication** for SMTP
- **Input validation** for all user-provided data
- **Secure temp file handling** with proper cleanup
- **Limited file permissions** (750 for sensitive directories)

### 📊 Performance

- **Optional parallel execution** for multiple checks
- **Query optimization** with proper indexes and hints
- **Configurable timeouts** for database operations
- **Efficient data collection** with minimal overhead
- **Caching of version detection** to avoid repeated queries

### 📚 Documentation

- **Comprehensive README.md** with:
  - Installation instructions
  - Configuration guide
  - Usage examples
  - Troubleshooting section
  - Contributing guidelines
- **Inline code documentation** with clear comments
- **Example configuration files**
- **CHANGELOG.md** (this file)

### 🗑️ Removed

- Hardcoded email credentials and domains
- Monolithic script structure
- Fixed HTML templates (now dynamic)
- Unsafe shell operations

### 📋 Migration Guide from v1.x to v2.0

1. **Backup your current setup**:
   ```bash
   cp -r HealthCheck_Informix HealthCheck_Informix.v1.backup
   ```

2. **Update to v2.0**:
   ```bash
   git pull origin main
   ```

3. **Run setup script**:
   ```bash
   ./setup.sh
   ```

4. **Migrate configuration**:
   - Extract your email settings from old script
   - Update `config/healthcheck.json` with your settings
   - Create `config/hosts.conf` from your old ARCHOSTS file

5. **Set environment variables**:
   ```bash
   export HEALTHCHECK_SMTP_PASSWORD='your-password'
   ```

6. **Test**:
   ```bash
   ./healthcheck.sh --no-email --verbose
   ```

### 🎯 Breaking Changes

- **Configuration format changed**: Old hardcoded values must be migrated to JSON config
- **Script name changed**: Use `./healthcheck.sh` instead of `./HealthCheck_Informix.sh`
- **File structure changed**: New modular structure with lib/ and modules/ directories
- **Environment variables**: SMTP password now required in env var instead of hardcoded
- **Hosts file format unchanged**: Still uses pipe-delimited format

### 🔮 Future Plans (v2.1+)

See [README.md](README.md#roadmap) for the complete roadmap.

---

## [1.0.0] - 2023-XX-XX

### Initial Release

- Basic health check functionality
- Backup status monitoring (BAR)
- DBSpace usage monitoring
- Table page usage monitoring
- System alerts collection
- Simple HTML report generation
- Email notification via mailx

---

## Version Numbering

- **Major version** (X.0.0): Breaking changes, major rewrites
- **Minor version** (1.X.0): New features, backwards compatible
- **Patch version** (1.0.X): Bug fixes, small improvements
