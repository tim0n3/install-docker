#!/bin/bash
################################################################################
# Author:      Senior Systems Engineer
# Version:     2.0.0
# Repository:  internal/infrastructure-scripts
# Filename:    docker.sh
# Purpose:     Orchestrates Docker Engine installation across multiple distros.
#
# Description:
#   - Sources library files for logging (lib/logger.sh) and OS detection (lib/sleuth.sh).
#   - Removes conflicting container packages (Podman, old Docker).
#   - Configures official Docker repositories securely.
#   - Installs Docker CE, CLI, Containerd, and Compose v2.
#   - Enables and verifies systemd services.
#
# Process Flow:
#   1. Root Check -> 2. Load Libs -> 3. Detect OS -> 4. Clean Conflicts
#   5. Setup Repo -> 6. Install Pkgs -> 7. Enable Service -> 8. Verify
#
# Usage:
#   sudo ./docker.sh
################################################################################

# ==============================================================================
# PREAMBLE & LIBRARY LOADING
# ==============================================================================

# Script Directory Resolution
readonly SCRIPT_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

# Function: check_root
# Enforces execution as root user to avoid inline sudo complexity.
check_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        printf "CRITICAL: This script must be run as root.\n" >&2
        exit 1
    fi
}

# Run root check immediately
check_root

# Source Libraries
# We use a loop to ensure files exist before sourcing to fail fast.
for lib in "logger.sh" "sleuth.sh"; do
    if [[ -f "${SCRIPT_DIR}/lib/${lib}" ]]; then
        # shellcheck source=/dev/null
        . "${SCRIPT_DIR}/lib/${lib}"
    else
        printf "CRITICAL: Library %s not found in %s/lib/.\n" "$lib" "$SCRIPT_DIR" >&2
        exit 1
    fi
done

# Initialize Logging
init_logging

# Detect OS Context (Sets OS_ID, OS_CODENAME, PKG_MANAGER)
detect_os || exit 1

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Function: run_quiet
# Purpose:  Runs a command quietly and records output in the log file.
#           On failure, logs a single error line and returns non-zero.
run_quiet() {
    local desc="$1"
    shift

    if [[ -n "$LOG_FILE" ]]; then
        "$@" >>"$LOG_FILE" 2>&1
    else
        "$@" &> /dev/null
    fi

    local rc=$?
    if [[ $rc -ne 0 ]]; then
        local hint=""
        if [[ -n "$LOG_FILE" ]]; then
            hint=" See $LOG_FILE for details."
        fi
        log "ERROR" "${desc} failed.${hint}"
        return $rc
    fi

    return 0
}

# Function: cleanup_conflicting_packages
# Purpose:  Removes old versions and conflicting tools (Podman/Buildah on RHEL).
#           Idempotent: Package managers generally handle "not installed" gracefully.
cleanup_conflicting_packages() {
    log "INFO" "Scanning for conflicting packages..."

    local DEBS="docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
    local RPMS="docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman buildah"
    case "$PKG_MANAGER" in
        apt)
            # List of packages to remove for Debian/Ubuntu
            # suppressing stdout to keep logs clean, errors go to log file via redirection if we were piping,
            # but here we rely on apt's own output control or just let it flow to stdout.
            # We use DEBIAN_FRONTEND=noninteractive to prevent blocking.
            log "INFO" "Removing all conflicting packages"
            export DEBIAN_FRONTEND=noninteractive
            apt-get remove -yqq $DEBS &> /dev/null
            log "INFO" "Conflicting packages have been removed, or there were none."
            ;;
        dnf)
            # RHEL/CentOS often ships with Podman. Docker CE conflicts with it.
            log "INFO" "Removing all conflicting packages"
            dnf remove -y $RPMS &> /dev/null
            log "INFO" "Conflicting packages have been removed, or there were none."
            ;;
    esac
    log "SUCCESS" "Cleanup phase completed."
}

# Function: setup_repositories
# Purpose:  Configures the upstream Docker CE repository.
#           Handles GPG keys for Apt and Config Manager for DNF.
setup_repositories() {
    log "INFO" "Configuring Docker repositories for $OS_ID ($OS_CODENAME)..."

    case "$PKG_MANAGER" in
        apt)
            # 1. Install prerequisites
            # For POSIX Compliance use: -qq > /dev/null 2>&1
            log "INFO" "Installing prerequisites"
            run_quiet "Apt update (base)" apt-get update -qq || return 1
            run_quiet "Install prerequisites" apt-get install -yqq ca-certificates curl gnupg || return 1

            # 2. Setup Keyrings
            log "INFO" "Setting up Keyrings"
            run_quiet "Create keyrings directory" install -m 0755 -d /etc/apt/keyrings || return 1
            # Download key strictly if it changed or doesn't exist
            run_quiet "Fetch Docker GPG key" curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" -o /etc/apt/keyrings/docker.asc || return 1
            chmod a+r /etc/apt/keyrings/docker.asc

            # 3. Create Source File (Deb822 format preferred now, but sticking to standard list for broad compat)
            # We use the detected OS_ID (ubuntu/debian) and OS_CODENAME (noble/bookworm/etc)
            # We detect architecture dynamically to avoid hardcoding [arch=amd64]
            log "INFO" "Creating Docker sources file (Deb822)"
            local arch
            arch="$(dpkg --print-architecture)"

            # Using tee for file creation
            cat <<EOF > /etc/apt/sources.list.d/docker.sources
Types: deb
URIs: https://download.docker.com/linux/${OS_ID}
Suites: ${OS_CODENAME}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
            log "INFO" "Refreshing package index for Docker"
            run_quiet "Apt update (Docker repo)" apt-get update -qq || return 1
            ;;

        dnf)
            # Install core plugins for repo management
            log "INFO" "Installing prerequisites"
            run_quiet "Install DNF plugins" dnf install -y dnf-plugins-core || return 1

            local repo_url=""
            if [[ "$OS_ID" == "fedora" ]]; then
                repo_url="https://download.docker.com/linux/fedora/docker-ce.repo"
            else
                # For RHEL/CentOS/Rocky/Alma, we use the CentOS repo
                repo_url="https://download.docker.com/linux/centos/docker-ce.repo"
            fi

            log "INFO" "Adding Docker repo"
            run_quiet "Add Docker repo" dnf config-manager --add-repo "$repo_url" || return 1
            ;;
    esac
    log "SUCCESS" "Repository configuration completed."
}

# Function: install_packages
# Purpose:  Installs the core Docker engine packages.
install_packages() {
    log "INFO" "Installing Docker Engine and Compose plugin..."

    local PKGS="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

    case "$PKG_MANAGER" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            run_quiet "Install Docker packages" apt-get install -yqq $PKGS || return 1
            ;;
        dnf)
            run_quiet "Install Docker packages" dnf install -y $PKGS || return 1
            ;;
    esac
    log "SUCCESS" "Package installation completed."
}

# Function: enable_services
# Purpose:  Ensures the service starts on boot and runs now.
enable_services() {
    log "INFO" "Enabling systemd services..."

    # Enable and start immediately
    if systemctl enable --now docker &> /dev/null; then
        log "SUCCESS" "Service 'docker' enabled and started."
    else
        log "ERROR" "Failed to enable 'docker' service."
        return 1
    fi

    # Containerd is usually managed by docker, but enabling it explicitly is safe practice
    systemctl enable --now containerd &> /dev/null
}

# Function: verify_installation
# Purpose:  Sanity checks to ensure binaries run and version is reported.
verify_installation() {
    log "INFO" "Verifying installation..."

    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker binary not found in PATH."
        return 1
    fi

    # Check version
    local d_ver
    d_ver="$(docker --version)"
    log "INFO" "Installed: $d_ver"

    # Check Compose
    local c_ver
    c_ver="$(docker compose version)"
    log "INFO" "Installed: $c_ver"

    # Check running state (is the socket active?)
    if docker info >/dev/null 2>&1; then
        log "SUCCESS" "Docker is running and accessible."
    else
        log "WARN" "Docker is installed but the daemon appears unreachable. Check 'systemctl status docker'."
        return 1
    fi
}

# ==============================================================================
# MAIN CONTROLLER LOGIC
# ==============================================================================

# Execute Main
log "INFO" "Starting Docker install controller v2.0.0"

# 1. Clean old mess
cleanup_conflicting_packages

# 2. Set up upstream repos
setup_repositories

# 3. Install
install_packages

# 4. Service Start
enable_services

# 5. Verify
verify_installation || {
    log "ERROR" "Verification failed. Please review logs."
    exit 1
}

log "SUCCESS" "Docker installation completed successfully!"
