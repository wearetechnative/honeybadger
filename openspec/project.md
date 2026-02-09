# Project Context

## Purpose
Honeybadger is a Personal Device Audit tool for ISO27001 compliance. It
performs comprehensive security audits on Linux and macOS systems, generating
detailed reports about system security posture, configuration, and compliance
status.

The tool is designed to "make your computer as tough as a honeybadger" by
thoroughly auditing device security configurations.

## Tech Stack
- Bash (shell scripting for main orchestration)
- Docker (for running lynis-report-converter)
- Lynis (security auditing tool)
- Perl (for report conversion tools)
- Debian (container base image)

### Key Tools
- **neofetch**: System information display
- **lynis**: System security auditing
- **lynis-report-converter**: Converts Lynis reports to JSON/Excel formats
- **tar**: Report packaging and compression

## Project Conventions

### Code Style
- Bash scripts follow traditional Unix shell conventions
- Use RUNME.sh framework for command management
- Dependency checking before execution
- OS-specific code paths for Linux vs macOS

### Architecture Patterns
- **Main script**: RUNME.sh orchestrates all operations
- **Container-based conversion**: Docker isolates report conversion dependencies
- **Multi-format output**: Reports generated in multiple formats (JSON, text)
- **Comprehensive data collection**: System info, security audit, package lists, lock screen configs

### Testing Strategy
- Dependency validation before execution (checkdeps function)
- OS detection to ensure compatibility
- Error handling for missing tools

### Git Workflow
- Main branch: `main`
- Feature branches for development
- VERSION-honeybadger file tracks version information

## Domain Context

### Security Audit Scope
The tool audits and reports on:
1. **System Security**: Via Lynis comprehensive security scan
2. **System Information**: Hardware, OS, distribution details
3. **Installed Packages**: Complete package inventory (dpkg, rpm, pacman, nix)
4. **Block Devices**: Disk encryption and storage configuration
5. **Screen Lock Configuration**: Auto-lock settings across multiple desktop environments
   - GNOME (gsettings)
   - KDE Plasma (kscreenlockerrc)
   - XFCE (xfconf)
   - Hyprland/Sway (config files, hypridle/swayidle)
   - Generic X11 (xautolock, xss-lock)

### ISO27001 Compliance
The tool specifically targets ISO27001 compliance requirements for personal device security, ensuring devices meet organizational security standards.

## Important Constraints

### Platform Support
- Primary: Linux distributions (Debian, Ubuntu, Fedora, Arch, NixOS)
- Secondary: macOS
- Requires root/sudo access for Lynis audit

### Runtime Requirements
- Docker must be installed and running
- Sufficient permissions to read system logs (/var/log/lynis-report.dat)
- Network access for Docker image building (on first run)

### Output Format
- Reports packaged as .tar.bz2 archives
- Naming convention: honeybadger-{username}-{date}.tar.bz2
- Output directory: output-{username}-{date}/

## External Dependencies

### Required Tools
- **lynis**: https://github.com/CISOfy/lynis - Security auditing tool
- **docker**: Container runtime for report conversion
- **neofetch**: https://github.com/dylanaraps/neofetch - System info display
- **tar**: Archive creation
- **sed**: Text processing

### Docker Image Components
Built from `debian:sid` with:
- **lynis-report-converter**: https://github.com/d4t4king/lynis-report-converter
- **Perl modules**:
  - HTML::HTMLDoc (0.10)
  - Excel::Writer::XLSX (0.95)
  - XML::Writer
  - Archive::Zip
  - JSON
- **htmldoc**: HTML to PDF conversion

### Optional Dependencies
- **lsb_release**: Linux distribution information
- **gsettings**: GNOME desktop settings
- **xfconf-query**: XFCE configuration query
- **kreadconfig5/6**: KDE configuration reader

## Copyright & Ownership
Copyright Technative 2024
Created by Pim, et al.
Repository: http://github.com/wearetechnative/personal-device-audit
