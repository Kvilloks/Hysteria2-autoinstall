# Hysteria2 + SOCKS5 Proxy Farm Auto-Installer 🚀

A production-ready bash script to deploy a robust, anti-detect proxy farm (Hysteria2 & MicroSocks) on Linux servers with multiple IPs. Designed specifically to bypass advanced anti-fraud systems and game anti-cheats (perfect for AdsPower and bot farms).

## ✨ Key Features
*   **Multi-IP Architecture:** Automatically creates isolated routing tables for each IP address to prevent collisions.
*   **Advanced Anti-Detect:** TCP BBR, TTL=128 (Windows OS spoofing), and locked DNS to prevent provider leaks.
*   **Network Obfuscation:** Injects randomized ping delay (5-12ms) and jitter (2-6ms) via `tc netem` to perfectly mimic residential ISP connections.
*   **Google Sheets Export:** Automatically sends generated credentials and proxy links directly to your Google Sheet via Webhook.
*   **High Availability:** Tuned system limits (`LimitNOFILE`, `ip_nonlocal_bind`, `network-online.target`) to survive reboots and handle high loads.

## ⚙️ Quick Start

Run the script as `root` on your Ubuntu/Debian server.

### Option 1: Standard Installation (Local output only)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh)
```

### Option 2: Installation with Google Sheets Export (Recommended)
To automatically save proxy credentials to your Google Sheet, pass the `WEBHOOK_URL` and `SHEET_NAME` variables:

```bash
curl -k -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && WEBHOOK_URL="YOUR_WEBHOOK_URL_HERE" SHEET_NAME="Sheet1" /tmp/install-hysteria2.sh
```

## 📋 How it works
1. The script scans your server and prompts you to select an available IP address.
2. Asks if you want to install an additional SOCKS5 proxy on that specific IP.
3. Generates a random username and secure base64 password.
4. Configures systemd services, applies anti-detect network rules, and outputs (or exports) the final connection links and QR codes.
