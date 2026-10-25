#!/usr/bin/env bash
# Creates the aos-agents Docker network and stops containers on it reaching the internal
# network, except allow-listed host:port pairs. Internet access stays open (decision D4).
# Run as root on each Docker host (rootful Docker). Safe to run repeatedly.
# Settings come from /etc/default/aos-egress (see aos-egress.default.example).
set -euo pipefail

[[ -r /etc/default/aos-egress ]] && . /etc/default/aos-egress

NETWORK="${AOS_AGENT_NETWORK:-aos-agents}"
SUBNET="${AOS_AGENT_SUBNET:-172.30.0.0/16}"
ALLOW="${AOS_INTERNAL_ALLOW:-}"   # e.g. "10.1.2.3:443 10.1.2.4:4000"
CHAIN=AOS-EGRESS
PRIVATE_RANGES="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10"

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  docker network create --driver bridge --subnet "$SUBNET" "$NETWORK" >/dev/null
fi

# Rebuild our chain from scratch each run.
iptables -N "$CHAIN" 2>/dev/null || iptables -F "$CHAIN"
iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
iptables -A "$CHAIN" -d "$SUBNET" -j RETURN                       # containers on the same network
iptables -A "$CHAIN" -p udp --dport 53 -j RETURN                  # DNS
iptables -A "$CHAIN" -p tcp --dport 53 -j RETURN
for hp in $ALLOW; do
  iptables -A "$CHAIN" -p tcp -d "${hp%:*}" --dport "${hp##*:}" -j RETURN
done
for net in $PRIVATE_RANGES; do
  iptables -A "$CHAIN" -d "$net" -j REJECT --reject-with icmp-net-prohibited
done
iptables -A "$CHAIN" -j RETURN                                    # everything else: internet

# DOCKER-USER is created by Docker and evaluated before Docker's own forwarding rules.
iptables -C DOCKER-USER -s "$SUBNET" -j "$CHAIN" 2>/dev/null \
  || iptables -I DOCKER-USER -s "$SUBNET" -j "$CHAIN"

echo "aos-egress: $NETWORK ($SUBNET) internet allowed, private ranges blocked, allowed: ${ALLOW:-none}"
