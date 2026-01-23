# Changelog

All notable changes to this project are documented in this file.

## [2.0.0] - 2026-01-23
### Added
- Production-ready documentation set: quick start, requirements, checklist, troubleshooting, and technical design.
- Structured logging with log file output and quiet command execution.
- OS detection for Debian/Ubuntu and RHEL-family/Fedora.

### Changed
- Refactored `docker.sh` into a fail-fast, multi-distro installer with repo setup, cleanup, service enablement, and verification.
- Improved idempotency for DNF cleanup and repo add steps.
- Updated README to link all support documents and list supported distros.

### Removed
- SUSE/OpenSUSE (zypper) support.
