#!/bin/bash
set -euo pipefail

# Traefik is disabled: this project isn't using it, and an unused ingress
# controller is just more attack surface and CPU for a t3.small to carry.
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" INSTALL_K3S_SKIP_SELINUX_RPM=true sh -s - --disable traefik

# Written only on success (set -e above stops the script before this line
# runs if the install failed), so its presence is a reliable signal to
# check over SSM.
echo "k3s ${k3s_version} install finished at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /var/log/k3s-install-done
