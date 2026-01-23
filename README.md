# install-docker

This repo installs Docker Engine on Linux hosts.
It is made for production use.
It runs one script: `docker.sh`.

## Quick start (the short version)
1. Go to the repo folder.
2. Run: `sudo ./docker.sh`
3. Check the install:
   - `docker --version`
   - `docker compose version`

## What it does
- Checks you are root
- Detects your OS and package tool
- Removes old or conflicting packages (like podman and old docker)
- Adds Docker's official download source
- Installs Docker Engine, CLI, containerd, and Compose v2
- Enables and starts system services (systemd)
- Verifies Docker works

## What it changes on the host
- Adds download source files and keys
  - `/etc/apt/keyrings/docker.asc`
  - `/etc/apt/sources.list.d/docker.sources`
  - `/etc/yum.repos.d/docker-ce.repo` (dnf)
- Installs packages
- Enables services: `docker`, `containerd`
- Writes a log file to `/var/log` (or the repo folder if `/var/log` is not writable)

## Supported Linux distros
- Ubuntu and Debian (apt)
- RHEL family: RHEL, CentOS, Rocky, Alma (dnf)
- Fedora (dnf)

## Docs
- [Quick start](docs/QUICKSTART.md)
- [Requirements](docs/REQUIREMENTS.md)
- [Production checklist](docs/PRODUCTION_CHECKLIST.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Technical design spec](docs/TECHNICAL_DESIGN.md)

## License
See `LICENSE`.
