# Technical Design Spec

## Purpose
Install Docker Engine in a safe and repeatable way across common Linux distros.

## Goals
- Use the official Docker download sources
- Remove known conflicting packages
- Install Docker Engine, CLI, containerd, and Compose v2
- Start services with systemd
- Verify the install and write logs

## What this does not do
- Uninstall Docker
- Work offline
- Fully harden or lock down Docker
- Manage daemon settings for you

## Big picture flow
1. Require root
2. Load library files
3. Detect OS and package tool
4. Remove conflicting packages
5. Configure the Docker download source
6. Install packages
7. Enable services
8. Verify install

## Main parts
### `docker.sh`
- Orchestrates the whole flow.
- Stops on errors and prints logs.
- Functions:
  - `check_root`
  - `cleanup_conflicting_packages`
  - `setup_repositories`
  - `install_packages`
  - `enable_services`
  - `verify_installation`

### `lib/logger.sh`
- Provides `init_logging` and `log`.
- Writes logs to `/var/log` if possible.
- Falls back to the current folder if needed.

### `lib/sleuth.sh`
- Reads `/etc/os-release`.
- Sets:
  - `OS_ID`
  - `OS_VERSION_ID`
  - `OS_CODENAME`
  - `PKG_MANAGER`
- Maps distros to package tools:
  - Ubuntu or Debian -> apt
  - RHEL family -> dnf
  - Fedora -> dnf
  - SLES or OpenSUSE -> zypper

## How download source setup works
### apt (Ubuntu and Debian)
- Installs `ca-certificates`, `curl`, and `gnupg`.
- Saves the Docker GPG key to `/etc/apt/keyrings/docker.asc`.
- Writes `/etc/apt/sources.list.d/docker.sources`.
- Runs `apt-get update`.

### dnf (RHEL family and Fedora)
- Installs `dnf-plugins-core`.
- Adds the Docker repo file from `download.docker.com`.
- Uses the Fedora repo for Fedora.
- Uses the CentOS repo for RHEL-family distros.

### zypper (SLES and OpenSUSE)
- Adds the Docker repo file from `download.docker.com`.
- Runs `zypper refresh`.

## Packages we install
- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`

## Service management
- Enables and starts `docker` with systemd.
- Enables and starts `containerd` with systemd.

## Verification
- Checks `docker --version`.
- Checks `docker compose version`.
- Runs `docker info` to confirm the service is reachable.

## Logs
- Log levels: INFO, WARN, ERROR, SUCCESS.
- Log file name: `docker_install_YYYYMMDD.log`.

## Safe to run again
- Package removals are safe if the package is not installed.
- Download source files are overwritten with current values.
- Installs are safe to re-run.

## When it can fail
- Unsupported OS -> script stops with an error.
- Repo or network errors -> install fails.
- Service start failure -> script exits non-zero.

## Safety notes
- The script must run as root.
- Removing Podman or old Docker may impact existing workloads.
- The Docker socket is powerful. Do not expose it to the network.

## How to test
- Run on each supported OS family.
- Confirm repo files were created.
- Confirm `docker` and `containerd` are active.

## Future ideas
- Add a dry-run mode.
- Allow version pinning.
- Add an uninstall helper.
