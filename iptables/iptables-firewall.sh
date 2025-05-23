#!/bin/bash

# v 1.0

set -euo pipefail

# Automatically locate required system tools
LSMOD=$(command -v lsmod)
MODPROBE=$(command -v modprobe)
IPTABLES=$(command -v iptables)
IPTABLES_SAVE=$(command -v iptables-save)
IPTABLES_RESTORE=$(command -v iptables-restore)
IP=$(command -v ip)
LOGGER=$(command -v logger)

# Default ruleset files
RULESET="/etc/iptables/rules.v4"
NEW_RULESET="/etc/iptables/rules.new"

# Log messages to syslog if logger exists
log() {
  [ -x "$LOGGER" ] && "$LOGGER" -p info "$1"
}

# Load necessary kernel modules
load_modules() {
  "$MODPROBE" iptable_filter iptable_mangle ip_conntrack ipt_LOG
}

# Flush all iptables rules and reset default policies
flush_chains() {
  for table in $(< /proc/net/ip_tables_names); do
    for chain in $("$IPTABLES" -t "$table" -S | grep '^:' | cut -d' ' -f1 | cut -c2-); do
      "$IPTABLES" -t "$table" -F "$chain"
    done
    "$IPTABLES" -t "$table" -X
  done

  for chain in INPUT FORWARD OUTPUT; do
    "$IPTABLES" -P "$chain" ACCEPT
  done
}

# Save current iptables ruleset
save_ruleset() {
  local cur_ruleset="${1:-$RULESET}"
  "$IPTABLES_SAVE" > "$cur_ruleset"
}

# Load iptables ruleset from file
load_ruleset() {
  local cur_ruleset="${1:-$RULESET}"
  "$IPTABLES_RESTORE" < "$cur_ruleset"
}

# Build a new ruleset from scratch
make_new_ruleset() {
  # Set default policies
  "$IPTABLES" -P INPUT DROP
  "$IPTABLES" -P FORWARD DROP
  "$IPTABLES" -P OUTPUT ACCEPT

  # Create and configure custom log chains
  "$IPTABLES" -N LOG_ACCEPT
  "$IPTABLES" -A LOG_ACCEPT -j LOG --log-prefix "ACCEPTED "
  "$IPTABLES" -A LOG_ACCEPT -j ACCEPT

  "$IPTABLES" -N LOG_DROP
  "$IPTABLES" -A LOG_DROP -p udp --sport 137:139 -j DROP
  "$IPTABLES" -A LOG_DROP -p udp --dport 137:139 -j DROP
  "$IPTABLES" -A LOG_DROP -j LOG --log-prefix "DROPPED "
  "$IPTABLES" -A LOG_DROP -j DROP

  "$IPTABLES" -N LOG_REJECT
  "$IPTABLES" -A LOG_REJECT -j LOG --log-prefix "REJECTED "
  "$IPTABLES" -A LOG_REJECT -p tcp -j REJECT --reject-with tcp-reset
  "$IPTABLES" -A LOG_REJECT -j REJECT --reject-with icmp-host-unreachable

  # Accept traffic on loopback
  "$IPTABLES" -A INPUT -i lo -j ACCEPT
  "$IPTABLES" -A OUTPUT -o lo -j ACCEPT

  # Allow established/related connections
  "$IPTABLES" -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  # Source user-defined rules if file exists
  [ -r "$NEW_RULESET" ] && source "$NEW_RULESET"
}

# Ask for confirmation with timeout to allow recovery
confirm() {
  echo
  echo "YOU ARE THERE? PRESS ANY KEY TO CONFIRM, OR WAIT TO ROLLBACK..."
  echo

  cp -a "$RULESET" "${RULESET}.$(date +%Y%m%d%H%M%S)"
  save_ruleset

  log "Activating firewall script"
  flush_chains
  make_new_ruleset

  local recover=1
  for i in {9..1}; do
    echo -ne "\rRECOVERY IN $i SECONDS... "
    read -t1 -n1 -s && recover=0 && break
  done
  echo

  if (( recover == 1 )); then
    echo "Rollback: restoring previous ruleset..."
    flush_chains
    load_ruleset
  else
    echo "Firewall activated. Saving ruleset..."
    save_ruleset
  fi
}

# Show usage help
usage() {
  echo "Usage: $0 {start|stop|save|restore|flush}"
  exit 1
}

# Command-line interface
case "${1:-}" in
  start)
    confirm
    ;;
  stop)
    echo "Disabling firewall (accepting all)..."
    flush_chains
    ;;
  save)
    save_ruleset
    ;;
  restore)
    load_ruleset
    ;;
  flush)
    flush_chains
    ;;
  *)
    usage
    ;;
esac

exit 0
