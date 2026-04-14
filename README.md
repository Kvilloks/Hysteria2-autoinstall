# Hysteria2 Multi-IP Installer

A Bash script for automated deployment of Hysteria2 proxy servers on Linux servers with multiple IP addresses. The script resolves outbound traffic routing issues and applies network-level tweaks to hide proxy usage (Anti-Detect features).

## Features

*   **Isolated Routing:** Automatically configures `ip rule` and `ip route` (Policy Routing). This ensures that outbound traffic strictly routes through the specific IP address bound to the given Hysteria2 instance.
*   **TCP/IP Fingerprint Spoofing:**
    *   Modifies the outbound TTL to 128 (Windows standard) using `iptables`.
    *   Globally disables `tcp_timestamps` via `sysctl` to hide Linux kernel markers.
*   **Timing Analysis Protection:** Utilizes the `tc netem` kernel module to generate a unique static latency and jitter for each IP address.
*   **Process Isolation:** Each IP address is managed by its own dedicated systemd service. Network rules are applied dynamically on service start (`ExecStartPre`) and cleanly removed on stop (`ExecStopPost`).
*   **User Management:** Seamlessly appends new users to an existing configuration without overwriting current settings.
*   **Architecture Support:** Compatible with x86_64 (amd64) and aarch64 (arm64).

## Requirements

*   OS: Debian 11+ / Ubuntu 20.04+ (or derivatives).
*   Permissions: `root` access.
*   Network: Additional IP addresses must be pre-configured on the server's network interface prior to running the script.

## Installation and Run

You can download and execute the script in a single command with root privileges:

```bash
curl -k -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && /tmp/install-hysteria2.sh
```

## Usage

1. Upon launch, the script will scan the network interfaces and list all available IPv4 addresses.
2. Enter the index number corresponding to the desired IP address.
3. The script will automatically install dependencies (e.g., `yq`, `qrencode`, `iptables`), generate an SSL certificate, and create the configuration file.
4. Access credentials, a URI link (`hysteria2://...`), and a QR code for client configuration will be printed in the terminal.

To add another user to an already configured IP address, run the script again and select the same IP. The script will update the configuration accordingly.

## Traffic Masking Verification

You can verify the network fingerprint spoofing using traffic profilers:
1. Connect to the proxy from your client device.
2. Open the [BrowserLeaks IP Test](https://browserleaks.com/ip).
3. Scroll to the **TCP/IP Fingerprint** section. The **OS Type** should identify the traffic as `Windows` or `Windows NT`, instead of Linux or Android.
