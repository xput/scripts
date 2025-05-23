# iptables-firewall.sh

A modular and safe iptables firewall management script for Linux systems.

This script allows you to build, apply, save, and restore firewall rules with logging, rollback protection, and support for custom extensions. It is suitable for both local machines and servers.

---

## Table of Contents

* Features
* Requirements
* Installation
* Usage
* Commands
* Examples
* Custom Rules
* Safety Mechanism
* Files
* License

---

## Features

* Safe flushing and application of iptables rules
* 9-second interactive recovery window to prevent accidental lockout
* Automatic backup of current rules before changes
* Support for custom rules via `/etc/iptables/rules.new`
* Built-in logging chains for accepted, dropped, and rejected packets
* Stateful connection tracking using conntrack
* Simple command-line interface: `start`, `stop`, `save`, `restore`, `flush`

## Requirements

* Linux system with:

  * `iptables`
  * `modprobe`
  * `conntrack`
  * `logger`
* Root or sudo privileges

## Installation

1. Copy the script to your PATH and make it executable:

   ```bash
   sudo cp iptables-firewall.sh /usr/local/bin/iptables-firewall.sh
   sudo chmod +x /usr/local/bin/iptables-firewall.sh
   ```
2. Create the configuration directory and rule files:

   ```bash
   sudo mkdir -p /etc/iptables
   sudo touch /etc/iptables/rules.v4 /etc/iptables/rules.new
   ```

## Usage

Run the script as root or with sudo:

```bash
sudo iptables-firewall.sh <command>
```

## Commands

| Command | Description                                                            |
| ------- | ---------------------------------------------------------------------- |
| start   | Apply a new ruleset with a 9-second recovery window                    |
| stop    | Flush all rules and set default policies to ACCEPT (allow all traffic) |
| save    | Save the current active rules to `/etc/iptables/rules.v4`              |
| restore | Restore rules from `/etc/iptables/rules.v4`                            |
| flush   | Flush all rules and reset default policies to ACCEPT                   |

## Examples

* Apply the firewall (with rollback if not confirmed):

  ```bash
  sudo iptables-firewall.sh start
  ```
* Disable the firewall (allow all traffic):

  ```bash
  sudo iptables-firewall.sh stop
  ```
* Save the current ruleset:

  ```bash
  sudo iptables-firewall.sh save
  ```
* Restore the saved ruleset:

  ```bash
  sudo iptables-firewall.sh restore
  ```
* Flush all rules without applying a new ruleset:

  ```bash
  sudo iptables-firewall.sh flush
  ```

## Custom Rules (`/etc/iptables/rules.new`)

Place additional rules in `/etc/iptables/rules.new`. This file is sourced when running the `start` command. Use the `$IPTABLES` variable for consistency.

Example content of `/etc/iptables/rules.new`:

```bash
# Allow SSH from a trusted IP
$IPTABLES -A INPUT -p tcp --dport 22 -s 203.0.113.5 -m conntrack --ctstate NEW -j LOG_ACCEPT

# Allow ICMP (ping)
$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j LOG_ACCEPT

# Drop invalid packets
$IPTABLES -A INPUT -m conntrack --ctstate INVALID -j LOG_DROP

# Drop IP fragments
$IPTABLES -A INPUT -f -j LOG_DROP

# Reject all other incoming traffic
$IPTABLES -A INPUT -j LOG_REJECT

# Allow outbound DNS and HTTP/HTTPS
$IPTABLES -A OUTPUT -p udp --dport 53 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
```
## Make Rules Persistent

### Debian / Ubuntu

Install and enable `iptables-persistent`:

```bash
sudo apt-get install iptables-persistent
# follow prompts to save both IPv4 and IPv6 rules
```

## Safety Mechanism

When the `start` command is executed, the script waits for 9 seconds for a key press. If no key is pressed, it rolls back to the previously saved ruleset to prevent accidental lockout, which is especially useful over SSH.

## Files

| File                                  | Purpose                                       |
| ------------------------------------- | --------------------------------------------- |
| `/etc/iptables/rules.v4`              | Active and saved ruleset for save and restore |
| `/etc/iptables/rules.new`             | Optional custom rules sourced at startup      |
| `/usr/local/bin/iptables-firewall.sh` | Main firewall management script               |

## License

This project is licensed under the MIT License.
