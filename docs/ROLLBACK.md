# Rollback Procedures

## 1. Firewall
To reset the firewall to allow everything (DANGER):
```bash
nft flush ruleset
```

## 2. DNS
To restore default DNS:
```bash
chattr -i /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
systemctl stop unbound
```

## 3. Services
Disable Tier 2 services:
```bash
pkill -f services.py
```

Disable Tier 1 services:
```bash
systemctl stop caddy tor i2pd
```

## 4. Encrypted Swap
Turn off swap:
```bash
systemctl stop crypt-swap.service
swapoff -a
cryptsetup close swapcrypt
rm /swapfile
```
