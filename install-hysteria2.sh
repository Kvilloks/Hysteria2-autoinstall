#!/bin/bash

set -e

# Определение архитектуры сервера
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        HYS_ARCH="amd64"
        YQ_ARCH="amd64"
        ;;
    aarch64)
        HYS_ARCH="arm64"
        YQ_ARCH="arm64"
        ;;
    *)
        echo "❌ Архитектура $ARCH не поддерживается!"
        exit 1
        ;;
esac

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
        echo "❌ Ошибка: пожалуйста введит�� число от 1 до ${#IPS[@]}"
    fi
done

while true; do
    read -p "Установить дополнительно SOCKS5 прокси на этот IP? (1 - Да, 0 - Нет): " SOCKS_CHOICE
    if [[ "$SOCKS_CHOICE" == "0" || "$SOCKS_CHOICE" == "1" ]]; then
        break
    else
        echo "❌ Ошибка: введите 1 (Да) или 0 (Нет)."
    fi
done

echo ""
echo "✅ Выбран IP: $SELECTED_IP"
if [ "$SOCKS_CHOICE" == "1" ]; then
    echo "✅ SOCKS5: Будет установлен"
else
    echo "✅ SOCKS5: Установка пропущена"
fi
echo ""

IP_SAFE=$(echo $SELECTED_IP | tr '.' '_')
CONFIG_PATH="/etc/hysteria/config_${IP_SAFE}.yaml"
CERT_PATH="/etc/hysteria/cert_${IP_SAFE}.pem"
KEY_PATH="/etc/hysteria/key_${IP_SAFE}.pem"
SERVICE_NAME="hysteria-server-${IP_SAFE}"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
SOCKS_SERVICE_NAME="microsocks-${IP_SAFE}"
SOCKS_SERVICE_PATH="/etc/systemd/system/${SOCKS_SERVICE_NAME}.service"

# Уникальная таблица маршрутизации на основе последнего октета IP (например: 192.168.1.45 -> таблица 245)
LAST_OCTET=$(echo $SELECTED_IP | cut -d. -f4)
TABLE_ID=$((200 + LAST_OCTET % 50000)) # Защита от совпадений

# Получаем шлюз и интерфейс для маршрутизации
GATEWAY=$(ip route show | grep "^default" | awk '{print $3}' | head -1)
INTERFACE=$(ip route show | grep "^default" | awk '{print $5}' | head -1)

if [ -z "$GATEWAY" ] || [ -z "$INTERFACE" ]; then
    echo "⚠️ Внимание: Не удалось определить шлюз. Маршрутизация может работать некорректно."
    GATEWAY="127.0.0.1" 
    INTERFACE="eth0"
fi

# --- ГЛОБАЛЬНЫЙ АНТИДЕТЕКТ ОС (Отключение TCP Timestamps) ---
if ! grep -q "^net.ipv4.tcp_timestamps=0" /etc/sysctl.conf; then
    echo "🥷 Включение маскировки TCP/IP (отключение TCP Timestamps)..."
    echo "net.ipv4.tcp_timestamps=0" >> /etc/sysctl.conf
    sysctl -w net.ipv4.tcp_timestamps=0 > /dev/null 2>&1 || true
fi

# Базовые пакеты
PACKAGES="wget curl tar openssl qrencode python3 iptables iproute2"
if [ "$SOCKS_CHOICE" == "1" ]; then
    PACKAGES="$PACKAGES build-essential git"
fi

if [ ! -f "/usr/local/bin/hysteria" ] || { [ "$SOCKS_CHOICE" == "1" ] && [ ! -f "/usr/local/bin/microsocks" ]; }; then
  echo "📦 Установка зависимостей..."
  apt update
  apt install -y $PACKAGES
fi

# --- Установка Hysteria2 ---
if [ ! -f "/usr/local/bin/hysteria" ]; then
  if ! command -v yq &> /dev/null; then
    echo "📥 Установка yq (архитектура $YQ_ARCH)..."
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}"
    chmod +x /usr/local/bin/yq
  fi

  echo "⬇️  Получение последней версии Hysteria2..."
  VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name":' | cut -d'"' -f4)

  echo "📥 Скачивание Hysteria2 версия $VERSION (архитектура $HYS_ARCH)..."
  wget -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-${HYS_ARCH}"
  chmod +x /usr/local/bin/hysteria
else
  echo "✅ Hysteria2 уже установлен."
fi

# --- Установка SOCKS5 (microsocks) ---
if [ "$SOCKS_CHOICE" == "1" ] && [ ! -f "/usr/local/bin/microsocks" ]; then
  echo "📦 Компиляция MicroSocks..."
  cd /tmp
  rm -rf microsocks
  git clone https://github.com/rofl0r/microsocks.git
  cd microsocks
  make
  cp microsocks /usr/local/bin/
  cd ~
fi

if [ ! -f "$CONFIG_PATH" ]; then
  echo "🔐 Генерация сертификата для IP $SELECTED_IP..."
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$SELECTED_IP" 2>/dev/null
  chmod 600 "$KEY_PATH"

  echo "⚙️  Создание конфигурации Hysteria2..."
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
outbounds:
  - name: ip_outbound
    type: direct
    direct:
      bindIPv4: $SELECTED_IP
acl:
  inline:
    - ip_outbound(all)
EOF
  # Безопасность файла конфигурации (защита от чтения)
  chmod 600 "$CONFIG_PATH"

  # Генерируем уникальные сетевые отпечатки для этого IP
  MARK_ID=$(shuf -i 100-9999 -n 1)      # Уникальный ID для tc filter
  DELAY=$(shuf -i 5-12 -n 1)           # Базовый пинг (мс)
  JITTER=$(shuf -i 2-6 -n 1)            # Плавающий пинг (джиттер)

  echo "🔧 Создание systemd-сервиса Hysteria2 (Анти-Детект) для IP $SELECTED_IP..."
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Hysteria2 Server - $SELECTED_IP
After=network.target

[Service]
ExecStartPre=-/bin/bash -c "ip rule del from $SELECTED_IP table $TABLE_ID 2>/dev/null"
ExecStartPre=/bin/bash -c "ip rule add from $SELECTED_IP table $TABLE_ID"
ExecStartPre=/bin/bash -c "ip route replace default via $GATEWAY dev $INTERFACE table $TABLE_ID onlink"

ExecStartPre=-/bin/bash -c "iptables -t mangle -D POSTROUTING -s $SELECTED_IP -j TTL --ttl-set 128 2>/dev/null"
ExecStartPre=/bin/bash -c "iptables -t mangle -A POSTROUTING -s $SELECTED_IP -j TTL --ttl-set 128"

ExecStartPre=-/bin/bash -c "tc qdisc show dev $INTERFACE | grep -q 'htb' || tc qdisc add dev $INTERFACE root handle 1: htb default 10"
ExecStartPre=-/bin/bash -c "tc class show dev $INTERFACE | grep -q 'classid 1:10' || tc class add dev $INTERFACE parent 1: classid 1:10 htb rate 1000mbit"
ExecStartPre=-/bin/bash -c "tc class del dev $INTERFACE classid 1:$MARK_ID 2>/dev/null"
ExecStartPre=/bin/bash -c "tc class add dev $INTERFACE parent 1: classid 1:$MARK_ID htb rate 1000mbit"
ExecStartPre=/bin/bash -c "tc qdisc add dev $INTERFACE parent 1:$MARK_ID handle $MARK_ID: netem delay ${DELAY}ms ${JITTER}ms distribution normal"
ExecStartPre=/bin/bash -c "tc filter add dev $INTERFACE protocol ip parent 1:0 prio $MARK_ID u32 match ip src $SELECTED_IP flowid 1:$MARK_ID"

ExecStart=/usr/local/bin/hysteria server -c $CONFIG_PATH
Restart=on-failure
User=root
Environment="GODEBUG=madvdontneed=1"

ExecStopPost=-/bin/bash -c "ip rule del from $SELECTED_IP table $TABLE_ID 2>/dev/null"
ExecStopPost=-/bin/bash -c "iptables -t mangle -D POSTROUTING -s $SELECTED_IP -j TTL --ttl-set 128 2>/dev/null"
ExecStopPost=-/bin/bash -c "tc filter del dev $INTERFACE protocol ip parent 1:0 prio $MARK_ID 2>/dev/null"
ExecStopPost=-/bin/bash -c "tc class del dev $INTERFACE classid 1:$MARK_ID 2>/dev/null"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  echo "🚀 Запуск Hysteria2 на IP $SELECTED_IP..."
  systemctl enable --now $SERVICE_NAME

  if [ "$SOCKS_CHOICE" == "1" ]; then
    echo "🔧 Создание systemd-сервиса SOCKS5 для IP $SELECTED_IP..."
    cat > "$SOCKS_SERVICE_PATH" <<EOF
[Unit]
Description=MicroSocks Server - $SELECTED_IP
After=network.target

[Service]
ExecStart=/usr/local/bin/microsocks -1 -i $SELECTED_IP -b $SELECTED_IP -p 1080 -u $NEW_USER -P $NEW_PASS
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    chmod 600 "$SOCKS_SERVICE_PATH"
    systemctl daemon-reload
    echo "🚀 Запуск SOCKS5 на IP $SELECTED_IP..."
    systemctl enable --now $SOCKS_SERVICE_NAME
  fi

else
  echo "⚙️  Обновление конфигурации Hysteria2 для IP $SELECTED_IP..."
  if ! command -v yq &> /dev/null; then
    apt update
    apt install -y wget
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}"
    chmod +x /usr/local/bin/yq
  fi

  yq -i '.auth.type = "userpass"' "$CONFIG_PATH"

  if ! yq eval '.auth.userpass' "$CONFIG_PATH" &>/dev/null || [ "$(yq eval '.auth.userpass' "$CONFIG_PATH")" = "null" ]; then
    yq -i '.auth.userpass = {}' "$CONFIG_PATH"
  fi

  if ! yq eval ".auth.userpass.$NEW_USER" "$CONFIG_PATH" &>/dev/null || [ "$(yq eval ".auth.userpass.$NEW_USER" "$CONFIG_PATH")" = "null" ]; then
    yq -i ".auth.userpass.\"$NEW_USER\" = \"$NEW_PASS\"" "$CONFIG_PATH"
  fi

  if [ "$(yq eval '.outbounds' "$CONFIG_PATH")" = "null" ]; then
    echo "🔧 Добавление привязки IP (outbounds) в существующий конфиг..."
    yq -i '.outbounds = [{"name": "ip_outbound", "type": "direct", "direct": {"bindIPv4": "'$SELECTED_IP'"}}]' "$CONFIG_PATH"
    yq -i '.acl.inline = ["ip_outbound(all)"]' "$CONFIG_PATH"
  fi

  echo "🔄 Перезапуск Hysteria2 для IP $SELECTED_IP..."
  systemctl restart $SERVICE_NAME
  
  if [ "$SOCKS_CHOICE" == "1" ]; then
    echo "⚠️ ВНИМАНИЕ: Так как вы добавляете юзера на уже существующий IP,"
    echo "⚠️ Hysteria2 сохранит старых пользователей, но SOCKS5 будет ПЕРЕЗАПИСАН."
    echo "⚠️ В SOCKS5 теперь будет работать только НОВЫЙ пользователь!"
    cat > "$SOCKS_SERVICE_PATH" <<EOF
[Unit]
Description=MicroSocks Server - $SELECTED_IP
After=network.target

[Service]
ExecStart=/usr/local/bin/microsocks -1 -i $SELECTED_IP -b $SELECTED_IP -p 1080 -u $NEW_USER -P $NEW_PASS
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    chmod 600 "$SOCKS_SERVICE_PATH"
    systemctl daemon-reload
    systemctl restart $SOCKS_SERVICE_NAME || systemctl enable --now $SOCKS_SERVICE_NAME
  fi
fi

# URL-encode пароль правильно
ENCODED_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$NEW_PASS', safe=''))")
HYST_LINK="hysteria2://$NEW_USER:$ENCODED_PASS@$SELECTED_IP:443/?insecure=1"
SOCKS_LINK="socks5://$NEW_USER:$ENCODED_PASS@$SELECTED_IP:1080"

echo ""
echo "=========================================="
echo "✅ ПРОКСИ УСПЕШНО УСТАНОВЛЕНЫ!"
echo "=========================================="
echo "IP Адрес:     $SELECTED_IP"
echo "Пользователь: $NEW_USER"
echo "Пароль:       $NEW_PASS"
echo "------------------------------------------"
echo "🟢 Hysteria2 (Порт: 443)"
echo "Сервис:       $SERVICE_NAME"
echo "Ссылка:"
echo "$HYST_LINK"

if [ "$SOCKS_CHOICE" == "1" ]; then
  echo "------------------------------------------"
  echo "🟡 SOCKS5 (Порт: 1080)"
  echo "Сервис:       $SOCKS_SERVICE_NAME"
  echo "Ссылка:"
  echo "$SOCKS_LINK"
fi

echo "=========================================="
echo ""

if command -v qrencode &> /dev/null; then
  echo "=== QR-код Hysteria2 для мобильного ==="
  qrencode -t ANSIUTF8 "$HYST_LINK"
  echo "======================================="
  echo ""
fi
