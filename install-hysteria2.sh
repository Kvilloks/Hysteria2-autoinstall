#!/bin/bash

# Автоматическая установка и настройка Hysteria2 сервера
# Скрипт устанавливает Hysteria2, создает конфигурацию, генерирует пароли
# и выводит QR-код для удобного подключения мобильных клиентов

set -e

# Пути к конфигурационным файлам Hysteria2
CONFIG_PATH="/etc/hysteria/config.yaml"
CERT_PATH="/etc/hysteria/cert.pem"
KEY_PATH="/etc/hysteria/key.pem"

# Обновление системы и установка необходимых пакетов
# qrencode - для генерации QR-кодов в терминале
apt update
apt install -y wget curl tar openssl qrencode

# 1. Установка Hysteria2
# Получаем последнюю версию из GitHub API и скачиваем исполняемый файл
VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d '"' -f 4)
wget -O /tmp/hysteria.tar.gz https://github.com/apernet/hysteria/releases/download/${VERSION}/hysteria-linux-amd64.tar.gz
tar -xzf /tmp/hysteria.tar.gz -C /usr/local/bin
chmod +x /usr/local/bin/hysteria

# 2. Генерация самоподписанного сертификата (если не существует)
# Сертификат необходим для TLS шифрования трафика
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
  mkdir -p /etc/hysteria
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=$(hostname)"
fi

# 3. Генерация нового случайного пароля для пользователя
# Используем base64 для создания удобочитаемого пароля
NEW_PASS=$(openssl rand -base64 12)

# 4. Подготовка конфигурации (объединение/добавление пароля)
# Скрипт может работать с существующими конфигурациями, добавляя новые пароли
if [ -f "$CONFIG_PATH" ]; then
  # Пытаемся добавить пароль к существующей конфигурации
  # Если уже есть массив паролей, добавляем; если строка, конвертируем в массив
  if grep -qE "passwords:" "$CONFIG_PATH"; then
    # Уже есть массив паролей, просто добавляем новый пароль
    sed -i "/passwords:/a\    - \"$NEW_PASS\"" "$CONFIG_PATH"
  elif grep -qE "password:" "$CONFIG_PATH"; then
    # Заменяем одиночный пароль на массив паролей
    OLD_PASS=$(grep 'password:' "$CONFIG_PATH" | head -n1 | awk -F': ' '{print $2}' | tr -d '"')
    sed -i "/password:/c\  passwords:\n    - \"$OLD_PASS\"\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  else
    # Нет пароля, добавляем массив паролей
    sed -i "/auth:/a\  passwords:\n    - \"$NEW_PASS\"" "$CONFIG_PATH"
  fi
else
  # Создаем новую конфигурацию с маскарадингом под Bing
  # Маскарадинг помогает скрыть трафик под обычные HTTPS запросы
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

# 5. Создание systemd службы (если не существует)
# Служба обеспечивает автоматический запуск сервера и перезапуск при сбоях
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

  # Перезагружаем systemd и запускаем службу
  systemctl daemon-reload
  systemctl enable --now hysteria-server
else
  # Если служба уже существует, просто перезапускаем её
  systemctl restart hysteria-server
fi

# 6. Вывод информации и генерация QR-кода
# Получаем внешний IP адрес сервера для клиентской ссылки
IP=$(curl -s https://api.ip.sb/ip || hostname -I | awk '{print $1}')

# Формируем ссылку для подключения клиента
CLIENT_URL="hysteria2://$NEW_PASS@$IP:443/?insecure=1"

echo "=============================="
echo "Hysteria2 пользователь добавлен!"
echo "Порт: 443"
echo "Новый пароль: $NEW_PASS"
echo "Сертификат: $CERT_PATH"
echo "=============================="
echo ""
echo "Ссылка для подключения клиента:"
echo "$CLIENT_URL"
echo ""
echo "QR-код для быстрого подключения с мобильного устройства:"
echo "Отсканируйте QR-код ниже в вашем Hysteria2 клиенте:"
echo ""
# Генерируем QR-код прямо в терминале для удобного сканирования
qrencode -t UTF8 "$CLIENT_URL"
echo ""
echo "Настройка завершена! Сервер Hysteria2 запущен и готов к подключениям."
