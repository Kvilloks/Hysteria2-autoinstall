#!/bin/bash

set -e

# ================================
# Hysteria2 Multi-User Auto-Install & Add-User Script
# by Kvilloks
#
# Каждый запуск скрипта добавляет нового пользователя (пароль) в конфиг Hysteria2.
# Старые пароли и сертификаты сохраняются. Сертификат создаётся только при первом запуске.
# Также теперь генерируется QR-код hysteria2:// для быстрого сканирования телефоном.
# ================================

CONFIG_PATH="/etc/hysteria/config.yaml"
CERT_PATH="/etc/hysteria/cert.pem"
KEY_PATH="/etc/hysteria/key.pem"

# 1. Обновление системы и установка зависимостей
apt update
apt install -y wget curl tar openssl qrencode

# 2. Получение последней версии Hysteria2 (корректно с app/)
VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | cut -d'"' -f4)

# 3. Скачивание и установка Hysteria2 (бинарник, не архив!)
wget -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64"
chmod +x /usr/local/bin/hysteria

# 4. Генерация самоподписанного сертификата, если его ещё нет
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$(hostname)"
fi

# 5. Генерация нового случайного пароля для пользователя
NEW_PASS=$(openssl rand -base64 12)

# 6. Добавление нового пароля в config.yaml
if [ -f "$CONFIG_PATH" ]; then
  # Если уже есть файл конфигурации:
  # - Если уже есть массив passwords: просто добавить новый пароль
  # - Если есть только строка password:, заменить её на passwords: массив со старым и новым паролем
  # - Если нет пароля — добавить массив с новым паролем
  if grep -qE "passwords:" "$CONFIG_PATH"; then
    sed -i "/passwords:/a\    - \"$NEW_PASS\"" "$CONFIG_PATH"
  elif grep -qE "password:" "$CONFIG_PATH"; then
    OLD_PASS=$(grep 'password:' "$CONFIG_PATH" | head -n1 | awk -F': ' '{print $2}' | tr -d '"')
    sed -i "/password:/c\  passwords:\n    - \"$OLD_PASS\"\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  else
    sed -i "/auth:/a\  passwords:\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  fi
else
  # Если конфиг отсутствует — создать новый с массивом паролей
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

# 7. Создание systemd-сервиса для Hysteria2 (только при первом запуске)
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
  # Если сервис уже есть — просто перезапустить с новым конфигом
  systemctl restart hysteria-server
fi

# 8. Вывод информации о новом пользователе (пароле) и ссылке для клиента
IP=$(curl -s https://api.ip.sb/ip || hostname -I | awk '{print $1}')
HYST_LINK="hysteria2://$NEW_PASS@$IP:443/?insecure=1"

echo "=============================="
echo "Hysteria2 user added!"
echo "Port: 443"
echo "New password: $NEW_PASS"
echo "Certificate: $CERT_PATH"
echo "=============================="
echo ""
echo "Your client URL:"
echo "$HYST_LINK"
echo ""

# 9. Генерация QR-кода hysteria2:// ссылки прямо в терминал
echo "=== QR-код для мобильного клиента ==="
qrencode -t ANSIUTF8 "$HYST_LINK"
echo "====================================="
echo "Отсканируйте этот QR-код камерой или в мобильном приложении-клиенте Hysteria2"
