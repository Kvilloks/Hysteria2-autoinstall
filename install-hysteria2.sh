#!/bin/bash

set -e

# 1. Update and install dependencies
apt update
apt install -y wget curl tar openssl

# 2. Get latest Hysteria2 release
VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d '"' -f 4)
wget -O /tmp/hysteria.tar.gz https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64.tar.gz
tar -xzf /tmp/hysteria.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/hysteria

# 3. Generate random password
PASS=$(openssl rand -base64 12)

# 4. Generate self-signed certificate
mkdir -p /etc/hysteria
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout /etc/hysteria/key.pem -out /etc/hysteria/cert.pem -subj "/CN=$(hostname)"

# 5. Generate config.yaml
cat > /etc/hysteria/config.yaml <<EOF
listen: :443
tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem
auth:
  type: password
  password: "$PASS"
masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com/
EOF

# 6. Create systemd service
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

# 7. Print connection info
IP=$(curl -s https://api.ip.sb/ip || hostname -I | awk '{print $1}')
echo "=============================="
echo "Hysteria2 installed and running!"
echo "Port: 443"
echo "Password: $PASS"
echo "Certificate: /etc/hysteria/cert.pem"
echo "=============================="
echo ""
echo "Sample Hysteria2 client URL:"
echo "hysteria2://$PASS@$IP:443/?insecure=1"
