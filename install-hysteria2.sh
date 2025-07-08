#!/bin/bash

set -e

CONFIG_PATH="/etc/hysteria/config.yaml"
CERT_PATH="/etc/hysteria/cert.pem"
KEY_PATH="/etc/hysteria/key.pem"

apt update
apt install -y wget curl tar openssl

# 1. Install Hysteria2
VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d '"' -f 4)
wget -O /tmp/hysteria.tar.gz https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64.tar.gz
tar -xzf /tmp/hysteria.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/hysteria

# 2. Generate self-signed certificate if not exists
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$(hostname)"
fi

# 3. Generate new random password
NEW_PASS=$(openssl rand -base64 12)

# 4. Prepare config (merge/add password)
if [ -f "$CONFIG_PATH" ]; then
  # Try to add password to existing config
  # If already array, append; if string, convert to array
  if grep -qE "passwords:" "$CONFIG_PATH"; then
    # Already passwords array, just append new password
    sed -i "/passwords:/a\    - \"$NEW_PASS\"" "$CONFIG_PATH"
  elif grep -qE "password:" "$CONFIG_PATH"; then
    # Replace single password with passwords array
    OLD_PASS=$(grep 'password:' "$CONFIG_PATH" | head -n1 | awk -F': ' '{print $2}' | tr -d '"')
    sed -i "/password:/c\  passwords:\n    - \"$OLD_PASS\"\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  else
    # No password, add passwords array
    sed -i "/auth:/a\  passwords:\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  fi
else
  # Create new config
  cat > "$CONFIG_PATH" <<EOF
listen: :443
tls:
  cert: $CERT_PATH
  key: $KEY_PATH
auth:
  passwords:
    - "$NEW_PASS"
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
EOF
fi

# 5. Create systemd service if not exist
if [ ! -f /etc/systemd/system/hysteria-server.service ]; then
cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now hysteria-server
else
  systemctl restart hysteria-server
fi

# 6. Output info
IP=$(curl -s https://api.ip.sb/ip || hostname -I | awk '{print $1}')
echo "=============================="
echo "Hysteria2 user added!"
echo "Port: 443"
echo "New password: $NEW_PASS"
echo "Certificate: $CERT_PATH"
echo "=============================="
echo ""
echo "Your client URL:"
echo "hysteria2://$NEW_PASS@$IP:443/?insecure=1"
