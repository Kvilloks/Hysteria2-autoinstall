#!/bin/bash

# Скрипт автоматической установки и настройки Hysteria2 сервера
# Автор: Kvilloks
# Описание: Устанавливает Hysteria2, генерирует сертификаты, настраивает конфиг и показывает QR-код для подключения

set -e

# Пути к файлам конфигурации и сертификатам
CONFIG_PATH="/etc/hysteria/config.yaml"
CERT_PATH="/etc/hysteria/cert.pem" 
KEY_PATH="/etc/hysteria/key.pem"

# Обновление системы и установка необходимых пакетов
echo "Обновление системы и установка зависимостей..."
apt update
apt install -y wget curl tar openssl qrencode

# 1. Установка Hysteria2
echo "1. Загрузка и установка последней версии Hysteria2..."
VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d '"' -f 4)
echo "Найдена версия: $VERSION"
wget -O /tmp/hysteria.tar.gz https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64.tar.gz
tar -xzf /tmp/hysteria.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/hysteria
echo "Hysteria2 успешно установлен!"

# 2. Генерация самоподписанного сертификата (если не существует)
echo "2. Проверка и генерация SSL-сертификата..."
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
  echo "Создание SSL-сертификата для домена $(hostname)..."
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$(hostname)"
  echo "SSL-сертификат создан успешно!"
else
  echo "SSL-сертификат уже существует, пропускаем создание"
fi

# 3. Генерация нового случайного пароля
echo "3. Генерация нового пароля пользователя..."
NEW_PASS=$(openssl rand -base64 12)
echo "Новый пароль сгенерирован: $NEW_PASS"

# 4. Подготовка конфигурации (добавление/объединение паролей)
echo "4. Настройка конфигурации Hysteria2..."
if [ -f "$CONFIG_PATH" ]; then
  echo "Обнаружен существующий конфиг, добавляем новый пароль..."
  # Попытка добавить пароль к существующей конфигурации
  # Если уже есть массив паролей, добавляем; если строка, конвертируем в массив
  if grep -qE "passwords:" "$CONFIG_PATH"; then
    # Уже есть массив паролей, просто добавляем новый
    echo "Добавляем пароль к существующему списку паролей"
    sed -i "/passwords:/a\    - \"$NEW_PASS\"" "$CONFIG_PATH"
  elif grep -qE "password:" "$CONFIG_PATH"; then
    # Заменяем одиночный пароль на массив паролей
    echo "Конвертируем одиночный пароль в массив паролей"
    OLD_PASS=$(grep 'password:' "$CONFIG_PATH" | head -n1 | awk -F': ' '{print $2}' | tr -d '"')
    sed -i "/password:/c\  passwords:\n    - \"$OLD_PASS\"\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  else
    # Нет паролей, добавляем массив паролей
    echo "Добавляем секцию паролей в конфиг"
    sed -i "/auth:/a\  passwords:\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  fi
else
  # Создание нового конфига
  echo "Создание нового файла конфигурации..."
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
  echo "Конфигурация создана с маскировкой под Bing.com"
fi

# 5. Создание systemd службы (если не существует)
echo "5. Настройка systemd службы..."
if [ ! -f /etc/systemd/system/hysteria-server.service ]; then
echo "Создание systemd службы для автозапуска..."
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

  echo "Запуск и включение службы в автозагрузку..."
  systemctl daemon-reload
  systemctl enable --now hysteria-server
  echo "Служба Hysteria2 запущена и добавлена в автозагрузку"
else
  echo "Служба уже существует, перезапускаем..."
  systemctl restart hysteria-server
  echo "Служба Hysteria2 перезапущена"
fi

# 6. Вывод информации о подключении
echo "6. Генерация данных для подключения..."
IP=$(curl -s https://api.ip.sb/ip || hostname -I | awk '{print $1}')
HYSTERIA_URL="hysteria2://$NEW_PASS@$IP:443/?insecure=1"

echo ""
echo "=============================="
echo "  Hysteria2 пользователь добавлен!"
echo "=============================="
echo "Порт: 443"
echo "Новый пароль: $NEW_PASS"
echo "Сертификат: $CERT_PATH"
echo "IP адрес: $IP"
echo "=============================="
echo ""
echo "Ссылка для клиента:"
echo "$HYSTERIA_URL"
echo ""
echo "QR-код для быстрого подключения:"
echo "--------------------------------"
qrencode -t UTF8 "$HYSTERIA_URL"
echo "--------------------------------"
echo ""
echo "Скопируйте ссылку выше или отсканируйте QR-код"
echo "для настройки вашего Hysteria2 клиента!"
echo ""
echo "Установка завершена успешно! 🎉"
