# Hysteria2-autoinstall

Automatic installer for [Hysteria2](https://github.com/apernet/hysteria) server with multi-IP support, SOCKS5 integration, and anti-fingerprint network optimizations for Linux (Debian/Ubuntu).

## Features

- Automatic detection and selection of public IP for the service
- Generates a unique user and strong password
- Optionally sets up a standalone SOCKS5 proxy on the chosen IP
- Automatically generates a TLS certificate for the selected IP
- Safe to run multiple times: adds new IPs and users or modifies SOCKS5 settings
- Anti-fingerprint global system networking tweaks (BBR, DNS, TTL, iptables, tc)
- Installs all needed dependencies automatically on first run
- Shows ready-to-use connection links and a QR code (for mobile clients)
- Optionally sends proxy data to Google Sheets via webhook

---

## Quick Start (one-liner installation)

**1. With Google Sheets integration**  
(replace `YOUR_WEBHOOK_URL` and `YOUR_SHEET` with your values)

```bash
curl -k -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && WEBHOOK_URL="YOUR_WEBHOOK_URL" SHEET_NAME="YOUR_SHEET" /tmp/install-hysteria2.sh
```

**2. Without Google Sheets integration**

```bash
curl -k -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && /tmp/install-hysteria2.sh
```

> All required dependencies will be installed automatically.

---

## How it works

1. The script detects all public IP addresses on your server and prompts you to select one.
2. Generates a secure username and password.
3. Installs and configures Hysteria2 and, optionally, a SOCKS5 proxy bound to the selected IP.
4. Applies secure DNS and network tuning for better anonymity and performance.
5. All settings are saved and loaded as independent systemd services.
6. At the end, ready-to-use connection links and a QR code are shown in the console.

---

## Updating & Re-running

- Rerun the script anytime to add a new configuration for another IP, generate a new user, or modify SOCKS5 parameters.
- All configurations, certificates, services, and passwords are generated and stored separately for each selected IP.

---

## Example connection links

- **Hysteria2:**  
  `hysteria2://USER:PASSWORD@IP:443/?insecure=1`

- **SOCKS5:**  
  `socks5://USER:PASSWORD@IP:1080`

- A QR code for Hysteria2 is also printed in the console (if `qrencode` is installed).

---

## Requirements

- Linux (Ubuntu/Debian; root access required)
- Network interface with public IP (VPS, dedicated, etc.)
- For QR code display — `qrencode` (will be installed if missing)

---

## Links

- [Hysteria2 project (upstream)](https://github.com/apernet/hysteria)
- [MicroSocks project (SOCKS5 proxy)](https://github.com/rofl0r/microsocks)


