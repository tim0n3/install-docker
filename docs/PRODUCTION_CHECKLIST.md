# Production Checklist

Use this list to keep installs safe on production hosts.

## Before you run
- Pick a change window and a rollback plan.
- Confirm the host is in the supported list.
- Make sure the host can reach `https://download.docker.com`.
- Know that old Docker packages and Podman may be removed.

## After you run
- Check services:
  - `systemctl status docker`
  - `systemctl status containerd`
- Check Docker:
  - `docker info`
  - `docker version`
- Decide on Docker settings in `/etc/docker/daemon.json`:
  - Where Docker stores data
  - How big logs can get
  - Registry mirrors if you need them
- Keep access safe:
  - Do not expose the Docker socket to the network.
  - Only add trusted users to the `docker` group.

## Rollback note
This repo does not include an uninstall script.
Use your OS package manager to remove Docker packages if needed.
