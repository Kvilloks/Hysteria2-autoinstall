#!/bin/bash

set -e

CONFIG_PATH="/etc/hysteria/config.yaml"
CERT_PATH="/etc/hysteria/cert.pem"
KEY_PATH="/etc/hysteria/key.pem"
SERVICE_PATH="/etc/systemd/system/hysteria-server.service"

# Получение всех IP-адресов с сервера
get_all_ips() {
    ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1
}

# Функция выбора IP-адреса
select_ip() {
    echo "=============================="
    echo "Доступные IP-адреса на сервере:"
    echo "=============================="
    
    # Получаем все IP в массив
    mapfile -t IPS < <(get_all_ips)
    
    # Если нет публичных IP, спросим вручную
    if [ ${#IPS[@]} -eq 0 ]; then
        echo "Не найдены публичные IP-адреса."
        read -p "Введите IP-адрес вручную: " MANUAL_IP
        echo "$MANUAL_IP"
        return
    fi
    
    # Показываем список IP с номерами
    for i in "${!IPS[@]}"; do
        echo "$((i+1)). ${IPS[$i]}"
    done
    
    echo ""
    read -p "Выберите номер IP (1-${#IPS[@]}): " IP_CHOICE
    
    # Проверяем корректность выбора
    if ! [[ "$IP_CHOICE" =~ ^[0-9]+$ ]] || [ "$IP_CHOICE" -lt 1 ] || [ "$IP_CHOICE" -gt ${#IPS[@]} ]; then
        echo "Ошибка: некорректный выбор!"
        exit 1
    fi
    
    # Возвращаем выбранный IP
    echo "${IPS[$((IP_CHOICE-1))]}"
}

# Генерация нового рандомного пользователя и пароля
NEW_USER="user$(shuf -i 1000-9999 -n 1)"
NEW_PASS=$(openssl rand -base64 12)

# Выбор IP-адреса
SELECTED_IP=$(select_ip)
echo "✓ Выбран IP: $SELECTED_IP"
echo ""

# Проверяем наличие основного конфига
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

  # Скачивание и установка Hysteria2
  wget -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64"
  chmod +x /usr/local/bin/hysteria

  # Генерация самоподписанного сертификата
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$(hostname)"

  # Создание базового config.yaml с выбранным IP
  cat > "$CONFIG_PATH" <<EOF
listen: $SELECTED_IP:443
tls:
  cert: $CERT_PATH
  key: $KEY_PATH
auth:
  type: userpass
  userpass:
    $NEW_USER: "$NEW_PASS"
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
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

else
  # Если конфиг уже есть — просто добавляем нового пользователя
  if ! command -v yq &> /dev/null; then
    apt update
    apt install -y wget
    wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  fi

  # Гарантируем что .auth.type = userpass
  yq -i '.auth.type = "userpass"' "$CONFIG_PATH"

  # Если .auth.userpass отсутствует — создаём пустой map
  if ! yq eval '.auth.userpass' "$CONFIG_PATH" &>/dev/null || [ "$(yq eval '.auth.userpass' "$CONFIG_PATH")" = "null" ]; then
    yq -i '.auth.userpass = {}' "$CONFIG_PATH"
  fi

  # Добавляем нового пользователя
  if ! yq eval ".auth.userpass.$NEW_USER" "$CONFIG_PATH" &>/dev/null || [ "$(yq eval ".auth.userpass.$NEW_USER" "$CONFIG_PATH")" = "null" ]; then
    yq -i ".auth.userpass.\"$NEW_USER\" = \"$NEW_PASS\"" "$CONFIG_PATH"
  fi

  # Перезапуск сервиса
  systemctl restart hysteria-server
fi

HYST_LINK="hysteria2://$NEW_USER:$NEW_PASS@$SELECTED_IP:443/?insecure=1"

echo "=============================="
echo "Hysteria2 user added!"
echo "Port: 443"
echo "IP Address: $SELECTED_IP"
echo "New user: $NEW_USER"
echo "New password: $NEW_PASS"
echo "Certificate: $CERT_PATH"
echo "=============================="
echo ""
echo "Your client URL:"
echo "$HYST_LINK"
echo ""

# Генерация QR-кода
if command -v qrencode &> /dev/null; then
  echo "=== QR-код для мобильного клиента ==="
  qrencode -t ANSIUTF8 "$HYST_LINK"
  echo "====================================="
  echo "Отсканируйте этот QR-код камерой или в мобильном приложении-клиенте Hysteria2"
fi
