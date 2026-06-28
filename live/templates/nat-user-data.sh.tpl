#!/bin/bash
set -euo pipefail

# Enable IPv4 forwarding so this instance can route traffic for the private subnet.
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-nat.conf

# Masquerade outbound traffic from the private subnet behind this instance's
# own (public) IP. The primary interface is detected at boot rather than
# hardcoded, since interface naming can vary by instance type.
PRIMARY_IFACE=$(ip -o -4 route show to default | awk '{print $5; exit}')
/sbin/iptables -t nat -A POSTROUTING -s ${private_subnet_cidr} -o "$PRIMARY_IFACE" -j MASQUERADE
/sbin/iptables -P FORWARD ACCEPT

# Persist the rules and restore them on every boot.
mkdir -p /etc/sysconfig
/sbin/iptables-save > /etc/sysconfig/iptables

cat > /etc/systemd/system/iptables-restore.service <<'UNIT'
[Unit]
Description=Restore iptables rules for NAT
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/sysconfig/iptables
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable iptables-restore.service
