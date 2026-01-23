# Quick Start

This is the shortest path to install Docker on one host.

## Steps
1. Open a terminal on the host.
2. Go to the repo folder.
3. Run: `sudo ./docker.sh`
4. Wait for this line: "Docker installation completed successfully!"
5. Check:
   - `docker --version`
   - `docker compose version`
   - `systemctl status docker`

## If you use automation
Run the script as root on each host. You can run it again if needed.

## If something breaks
See `docs/TROUBLESHOOTING.md`.
