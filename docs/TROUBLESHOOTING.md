# Troubleshooting

## "This script must be run as root"
Run with `sudo ./docker.sh` or log in as root.

## "Unsupported OS"
Your OS is not in the supported list. Check `/etc/os-release`.

## Repo or download errors
- Check internet access.
- Check DNS.
- If you use a proxy, set it for your package manager.

## Docker service is not running
- `systemctl status docker`
- `journalctl -u docker --no-pager`
- If containerd failed: `systemctl status containerd`

## Docker command not found
The install did not finish. Re-run the script and check the log.

## Where are logs?
Look for `docker_install_YYYYMMDD.log` in `/var/log` or in the repo folder.
