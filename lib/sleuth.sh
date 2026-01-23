#!/bin/bash
################################################################################
# Author:      Senior Systems Engineer
# Version:     1.1.2
# Repository:  internal/infrastructure-scripts
# Filename:    lib/sleuth.sh
# Purpose:     Provides OS and distribution detection logic.
#
# Description:
#   - Identifies OS ID, Version, and Codename.
#   - Maps distributions to package managers (apt/dnf).
#   - DEPENDENCY: Requires lib/logger.sh to be sourced first.
#
# Usage:
#   Source lib/logger.sh
#   Source this file: . ./lib/sleuth.sh
#   call detect_os
################################################################################

# ==============================================================================
# FUNCTION: detect_os
# ==============================================================================
# Purpose:  Identifies OS distribution and version using /etc/os-release.
#           Sets global variables for downstream logic.
# Global Vars Set:
#           OS_ID (ubuntu, debian, rhel, centos, fedora)
#           OS_VERSION_ID (e.g., 22.04, 9, 15.5)
#           OS_CODENAME (e.g., jammy, bookworm)
#           PKG_MANAGER (apt, dnf)
# Args:     None
# Returns:  0 on success, 1 on failure
# ==============================================================================
detect_os() {
    # 1. Dependency Check
    # Ensure 'log' function is available from logger.sh
    if ! command -v log >/dev/null 2>&1; then
        echo "CRITICAL: 'log' function not found. Please source lib/logger.sh first." >&2
        return 1
    fi

    log "INFO" "Starting OS detection..."

    if [[ ! -f "/etc/os-release" ]]; then
        log "ERROR" "File /etc/os-release not found. Cannot detect OS."
        return 1
    fi

    # Source the file directly (No piping/forking)
    # shellcheck source=/dev/null
    . /etc/os-release

    # ID is provided by os-release. We map it to our internal standards.
    # We use parameter expansion ${VAR,,} for lowercase normalization (Bash 4.0+)
    OS_ID="${ID,,}"
    OS_VERSION_ID="${VERSION_ID}"
    # Some distros don't strictly provide VERSION_CODENAME (like RHEL), handle defaults below.
    OS_CODENAME="${VERSION_CODENAME:-}"

    # Refine Detection Logic
    case "$OS_ID" in
        ubuntu|debian)
            PKG_MANAGER="apt"
            # Debian sometimes misses VERSION_CODENAME in older minimal images, extract from VERSION usually "11 (bullseye)"
            if [[ -z "$OS_CODENAME" && -n "$VERSION" ]]; then
                # Safe regex handling to prevent syntax errors
                local re='\(([^)]+)\)'
                if [[ "$VERSION" =~ $re ]]; then
                    OS_CODENAME="${BASH_REMATCH[1]}"
                fi
            fi
            ;;

        fedora)
            PKG_MANAGER="dnf"
            ;;

        centos|rhel|almalinux|rocky)
            PKG_MANAGER="dnf"
            # Normalize CentOS/Alma/Rocky to RHEL-compatible handling
            OS_ID="rhel"
            ;;

        *)
            log "ERROR" "Unsupported OS detected: $OS_ID"
            return 1
            ;;
    esac

    log "SUCCESS" "Detected OS: $OS_ID | Version: $OS_VERSION_ID | Codename: ${OS_CODENAME:-N/A} | Manager: $PKG_MANAGER"
}
