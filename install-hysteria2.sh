#!/bin/bash

set -e

get_all_ips() {
    ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1
}

select_ip() {
    IPS=($(get_all_ips))
    
    if [ ${#IPS[@]} -eq 0 ]; then
        echo "❌ Не найдены публичные IP-адреса."
        read -p "Введите IP-адрес вручную: " MANUAL_IP
        echo "$MANUAL_IP"
        return
    fi
    
    echo ""
    echo "=============================="
    echo "Доступные IP-адреса на сервере:"
    echo "=============================="
    for i in "${!IPS[@]}"; do
        echo "$((i+1)). ${IPS[$i]}"
    done
    echo "=============================="
    echo ""
}

NEW_USER="user$(shuf -i 1000-9999 -n 1)"
NEW_PASS=$(openssl rand -base64 12)

IPS=($(get_all_ips))
select_ip

while true; do
    read -p "Выберите номер IP (1-${#IPS[@]}): " IP_CHOICE
    
    if [[ "$IP_CHOICE" =~ ^[0-9]+$ ]] && [ "$IP_CHOICE" -ge 1 ] && [ "$IP_CHOICE" -le ${#IPS[@]} ]; then
        SELECTED_IP="${IPS[$((IP_CHOICE-1))]}"
        break
    else
        echo "❌ Ошибка: пожалуйста введите число от 1 до ${#IPS[@]}"
    fi
done

echo ""
echo "✅ Выбран IP: $SELECTED_IP"
echo ""

IP_SAFE=$(echo $SELECTED_IP | tr '.' '_')
CONFIG_PATH="/etc/hysteria/config_${IP_SAFE}.yaml"
CERT_PATH="/etc/hysteria/cert_${IP_SAFE}.pem"
KEY_PATH="/etc/hysteria/key_${IP_SAFE}.pem"
SERVICE_NAME="hysteria-server-${IP_SAFE}"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

if [ ! -f "/usr/local/bin/hysteria" ]; then
  echo "📦 Установка зависимостей..."
  apt update
  apt install -y wget curl tar openssl qrencode

  if ! command -v yq &> /dev/null; then
    echo "📥 Установка yq..."
    wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  fi

  echo "⬇️  Получение последней версии Hysteria2..."
  VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | cut -d'"' -f4)

  echo "📥 Скачивание Hysteria2 версия $VERSION..."
  wget -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64"
  chmod +x /usr/local/bin/hysteria
else
  echo "✅ Hysteria2 уже установлен, пропускаем установку зависимостей"
fi

if [ ! -f "$CONFIG_PATH" ]; then
  echo "🔐 Генерация сертификата для IP $SELECTED_IP..."
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$SELECTED_IP"

  echo "⚙️  Создание конфигурации Hysteria2..."
  cat > "$CONFIG_PATH" <<EOF
listen: $SELECTED_IP:443
outbound:
  direct:
    - type: tcp
      bind: $SELECTED_IP
    - type: udp
      bind: $SELECTED_IP
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

  echo "🔧 Создание systemd-сервиса для IP $SELECTED_IP..."
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Hysteria2 Server - $SELECTED_IP
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c $CONFIG_PATH
Restart=on-failure
User=root
Environment="GODEBUG=madvdontneed=1"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  echo "🚀 Запуск Hysteria2 на IP $SELECTED_IP..."
  systemctl enable --now $SERVICE_NAME

else
  echo "⚙️  Обновление конфигурации для IP $SELECTED_IP..."
  if ! command -v yq &> /dev/null; then
    apt update
    apt install -y wget
    wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  fi

  yq -i '.auth.type = "userpass"' "$CONFIG_PATH"

  if ! yq eval '.auth.userpass' "$CONFIG_PATH" &>/dev/null || [ "$(yq eval '.auth.userpass' "$CONFIG_PATH")" = "null" ]; then
    yq -i '.auth.userpass = {}' "$CONFIG_PATH"
  fi

  if ! yq eval ".auth.userpass.$NEW_USER" "$CONFIG_PATH" &>/dev/null || [ "$(yq eval ".auth.userpass.$NEW_USER" "$CONFIG_PATH")" = "null" ]; then
    yq -i ".auth.userpass.\"$NEW_USER\" = \"$NEW_PASS\"" "$CONFIG_PATH"
  fi

  echo "🔄 Перезапуск сервиса для IP $SELECTED_IP..."
  systemctl restart $SERVICE_NAME
fi

# КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: URL-encode пароль (заменяем / на %2F)
ENCODED_PASS=$(echo "$NEW_PASS" | sed 's/\//%2F/g')
HYST_LINK="hysteria2://$NEW_USER:$ENCODED_PASS@$SELECTED_IP:443/?insecure=1"

echo ""
echo "=============================="
echo "✅ Hysteria2 успешно установлен!"
echo "=============================="
echo "IP Адрес:     $SELECTED_IP"
echo "Порт:         443"
echo "Сервис:       $SERVICE_NAME"
echo "Пользователь: $NEW_USER"
echo "Пароль:       $NEW_PASS"
echo "=============================="
echo ""
echo "��� Ссылка для подключения:"
echo "$HYST_LINK"
echo ""

if command -v qrencode &> /dev/null; then
  echo "=== QR-код для мобильного клиента ==="
  qrencode -t ANSIUTF8 "$HYST_LINK"
  echo "====================================="
  echo "Отсканируйте этот QR-код в приложении Hysteria2"
  echo ""
fi

echo "=============================="
echo "📊 Активные Hysteria2 сервисы:"
echo "=============================="
systemctl list-units --all | grep hysteria-server || echo "Нет активных сервисов"
