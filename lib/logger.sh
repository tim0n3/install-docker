#!/bin/bash
################################################################################
# Author:      Senior Systems Engineer
# Version:     1.0.0
# Repository:  internal/infrastructure-scripts
# Filename:    lib/logger.sh
# Purpose:     Provides standardized logging functions and ANSI color definitions.
#
# Description:
#   - Defines logging primitives (INFO, WARN, ERROR, SUCCESS).
#   - Handles log file initialization and rotation context.
#   - Establishes color variables for terminal output.
#
# Usage:
#   Source this file FIRST in your main script: . ./lib/logger.sh
#   call init_logging
#   call log "INFO" "Message"
################################################################################

# ==============================================================================
# GLOBALS & CONSTANTS
# ==============================================================================

readonly TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"

# Default Log File - Will be verified in init_logging
DEFAULT_LOG_DIR="/var/log"
LOG_FILE=""

# ANSI Colors
# We use tput if available for safety, but hardcode fallbacks to ensure
# functionality if tput is missing in a bare environment.
if command -v tput >/dev/null 2>&1; then
    RESET="$(tput sgr0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
else
    RESET="\033[0m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
fi

# ==============================================================================
# FUNCTION: log
# ==============================================================================
# Purpose:  Logs messages to stdout (colored) and a log file (plain).
#           Prefers printf, falls back to echo.
# Args:     $1 (Level): INFO, WARN, ERROR, SUCCESS
#           $2 (Message): The text string to log
# Output:   Writes to stdout and $LOG_FILE
# ==============================================================================
log() {
    local level="$1"
    local message="$2"
    local color="$RESET"
    local timestamp

    # Calculate timestamp without forking 'date' if bash 4.2+ (printf %(fmt)T)
    # Fallback to date command if necessary.
    if [[ ${BASH_VERSINFO[0]} -ge 4 ]] && [[ ${BASH_VERSINFO[1]} -ge 2 ]]; then
        printf -v timestamp "%($TIMESTAMP_FORMAT)T" -1
    else
        timestamp="$(date +"$TIMESTAMP_FORMAT")"
    fi

    case "${level^^}" in
        "INFO")    color="$BLUE" ;;
        "WARN")    color="$YELLOW" ;;
        "ERROR")   color="$RED" ;;
        "SUCCESS") color="$GREEN" ;;
        *)         color="$RESET" ;;
    esac

    # Format the log string
    local log_string="[${timestamp}] [${level^^}] ${message}"

    # 1. Output to Console
    if command -v printf >/dev/null 2>&1; then
        printf "%b%s%b\n" "${color}" "${log_string}" "${RESET}"
    else
        echo -e "${color}${log_string}${RESET}"
    fi

    # 2. Output to File
    # Direct append, no piping.
    # Logic: Only write if LOG_FILE is defined and writable.
    if [[ -n "$LOG_FILE" ]] && [[ -w "$LOG_FILE" || -w "$(dirname "$LOG_FILE")" ]]; then
        # We write the plain string (sans color codes) to the file
        local plain_log_string="[${timestamp}] [${level^^}] ${message}"
        printf "%s\n" "$plain_log_string" >> "$LOG_FILE"
    fi
}

# ==============================================================================
# FUNCTION: init_logging
# ==============================================================================
# Purpose:  Sets up the log file location based on permissions.
# Args:     None
# Returns:  0 on success, 1 on error
# ==============================================================================
init_logging() {
    local log_filename="docker_install_$(date +%Y%m%d).log"

    # Check if we can write to /var/log (usually requires root)
    if [[ -w "$DEFAULT_LOG_DIR" ]]; then
        LOG_FILE="${DEFAULT_LOG_DIR}/${log_filename}"
    else
        # Fallback to current directory
        LOG_FILE="${PWD}/${log_filename}"
    fi

    # Initialize file
    if touch "$LOG_FILE" 2>/dev/null; then
        log "INFO" "Logging initialized. Writing to: $LOG_FILE"
    else
        # Critical failure in logging setup, dump to stderr
        echo "CRITICAL: Cannot write to log file at $LOG_FILE or /var/log." >&2
        return 1
    fi
}
