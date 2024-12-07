#!/bin/bash
#Ubuntu 18 web hardening script


# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update and upgrade the system
echo "Updating and upgrading the system..."
apt update && apt upgrade -y

# Install necessary tools and dependencies
echo "Installing necessary tools and dependencies..."
apt install -y curl wget nmap fail2ban iptables-persistent cron


#
#   IPTables Rules
#
#

# Configure firewall rules using iptables
echo "Configuring firewall rules..."

# Flush existing rules
iptables -F
iptables -X

# Set default policies
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Allow traffic from existing/established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow incoming HTTP traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow outgoing DNS traffic
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow outgoing NTP traffic
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT

# Allow Splunk forwarder traffic
iptables -A OUTPUT -p tcp --dport 9997 -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4
iptables -A OUTPUT -j LOG --log-prefix "IPTABLES-DROP:" --log-level 4

# Drop all other traffic
iptables -A INPUT -j DROP
iptables -A OUTPUT -j DROP
iptables -A FORWARD -j DROP

# Save iptables rules
iptables-save > /etc/iptables/rules.v4


#
#   Fail2Ban Configuration
#
#

# Enable and start Fail2ban
echo "Enabling and starting Fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Configure Fail2ban
echo "Configuring Fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit jail.local file
sed -i 's/bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
sed -i 's/findtime  = 10m/findtime  = 30m/' /etc/fail2ban/jail.local
sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local

# Add ignoreip (adjust as needed)
sed -i 's/ignoreip = 127.0.0.1\/8 ::1/ignoreip = 127.0.0.1\/8 ::1 172.20.0.0\/16/' /etc/fail2ban/jail.local

# Enable SSH protection
sed -i 's/\[sshd\]/[sshd]\nenabled = true/' /etc/fail2ban/jail.local

# Restart Fail2ban
echo "Restarting Fail2ban..."
systemctl restart fail2ban


#
#   Uninstall SSH, harden cron, final notes
#
#

# Uninstall SSH
echo "Uninstalling SSH..."
apt remove --purge openssh-server -y

# Harden cron
echo "Locking down Cron and AT permissions..."
touch /etc/cron.allow
chmod 600 /etc/cron.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/cron.deny

touch /etc/at.allow
chmod 600 /etc/at.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/at.deny

# Final steps
echo "Final steps..."
apt autoremove -y

echo "MAKE SURE YOU ENUMERATE!!!"
echo "Check for cronjobs, services on timers, etc, THEN RESTART THE MACHINE. IT WILL UPDATE TO A BETTER KERNEL!!!!!!"
