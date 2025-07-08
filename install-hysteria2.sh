#!/bin/bash

set -e

CONFIG_PATH="/etc/hysteria/config.yaml"
CERT_PATH="/etc/hysteria/cert.pem"
KEY_PATH="/etc/hysteria/key.pem"
SERVICE_PATH="/etc/systemd/system/hysteria-server.service"

# 1. Генерация нового логина и пароля для пользователя
NEW_USER="user$((RANDOM%9000+1000))"
NEW_PASS=$(openssl rand -base64 12)

# 2. Проверяем наличие основного конфига — если нет, это первый запуск (установка)
if [ ! -f "$CONFIG_PATH" ]; then
  # Обновление системы и установка зависимостей
  apt update
  apt install -y wget curl tar openssl qrencode

  # Установка yq для работы с YAML
  if ! command -v yq &> /dev/null; then
    wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  fi

  # Получение последней версии Hysteria2
  VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | cut -d'"' -f4)

  # Скачивание и установка Hysteria2 (бинарник)
  wget -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64"
  chmod +x /usr/local/bin/hysteria

  # Генерация самоподписанного сертификата
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$(hostname)"

  # Создание базового config.yaml с userpass
  cat > "$CONFIG_PATH" <<EOF
listen: :443
tls:
  cert: $CERT_PATH
  key: $KEY_PATH
auth:
  type: userpass
  users:
    $NEW_USER: "$NEW_PASS"
masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com/
EOF

  # Создание systemd-сервиса
  cat > "$SERVICE_PATH" <<EOF
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

# Если конфиг уже есть — просто добавляем нового пользователя
else
  # Установка yq, если не установлен (на случай, если удалили)
  if ! command -v yq &> /dev/null; then
    apt update
    apt install -y wget
    wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  fi

  # Гарантируем что .auth.type = userpass
  yq -i '.auth.type = "userpass"' "$CONFIG_PATH"

  # Если .auth.users не существует — создаём
  if ! yq '.auth.users' "$CONFIG_PATH" &>/dev/null; then
    yq -i '.auth.users = {}' "$CONFIG_PATH"
  fi

  # Добавляем нового пользователя (или заменяем если такой логин уже есть)
  yq -i '.auth.users["'"$NEW_USER"'"] = "'"$NEW_PASS"'"' "$CONFIG_PATH"

  # Перезапуск сервиса
  systemctl restart hysteria-server
fi

# Определяем внешний IP
IP=$(curl -s https://api.ipify.org)
if ! echo "$IP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  IP=$(hostname -I | awk '{print $1}')
fi

HYST_LINK="hysteria2://$NEW_USER:$NEW_PASS@$IP:443/?insecure=1"

echo "=============================="
echo "Hysteria2 user added!"
echo "Port: 443"
echo "Login: $NEW_USER"
echo "Password: $NEW_PASS"
echo "Certificate: $CERT_PATH"
echo "=============================="
echo ""
echo "Your client URL:"
echo "$HYST_LINK"
echo ""

# Генерация QR-кода hysteria2:// ссылки прямо в терминал (если qrencode есть)
if command -v qrencode &> /dev/null; then
  echo "=== QR-код для мобильного клиента ==="
  qrencode -t ANSIUTF8 "$HYST_LINK"
  echo "====================================="
  echo "Отсканируйте этот QR-код камерой или в мобильном приложении-клиенте Hysteria2"
fi
