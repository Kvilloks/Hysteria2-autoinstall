# Hysteria2 Auto Install Script

**English | [Русский](#русский)**

---

## Fast Hysteria2 Installation (One Command)

Run this command on your VPS (Ubuntu/Debian):

```bash
curl -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && dos2unix /tmp/install-hysteria2.sh 2>/dev/null || sed -i 's/\r$//' /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && bash /tmp/install-hysteria2.sh
```

- Installs the latest [Hysteria2](https://github.com/apernet/hysteria) server
- Generates a secure random password and self-signed certificate
- Starts Hysteria2 on port 443 with password authentication
- Outputs ready-to-use hysteria2:// link for your client
- **NEW:** Automatically generates and displays QR code for easy mobile setup

**Default masquerade: [https://www.bing.com/](https://www.bing.com/)**

---

## Connection Example

After install, you will see a link like:

```
hysteria2://YOUR_PASSWORD@YOUR_IP:443/?insecure=1
```

Plus a **QR code displayed in terminal** for easy mobile client setup!

Use this in your [Hysteria2 client](https://github.com/apernet/hysteria#clients)!

---

## Manual config and certificate

- Config path: `/etc/hysteria/config.yaml`
- Cert path: `/etc/hysteria/cert.pem`
- Key path: `/etc/hysteria/key.pem`

---

# Русский

## Быстрая установка Hysteria2 (одной командой)

Выполните на вашем сервере (Ubuntu/Debian):

```bash
curl -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && dos2unix /tmp/install-hysteria2.sh 2>/dev/null || sed -i 's/\r$//' /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && bash /tmp/install-hysteria2.sh
```

- Устанавливает последнюю версию [Hysteria2](https://github.com/apernet/hysteria)
- Генерирует пароль и самоподписанный сертификат
- Запускает сервер на порту 443 с авторизацией по паролю
- Показывает готовую ссылку hysteria2:// для клиента
- **НОВОЕ:** Автоматически генерирует и отображает QR-код для быстрой настройки

**Маскарадинг по умолчанию: [https://www.bing.com/](https://www.bing.com/)**

---

## Пример подключения

После установки увидите ссылку:

```
hysteria2://ВАШ_ПАРОЛЬ@IP_СЕРВЕРА:443/?insecure=1
```

Плюс **QR-код прямо в терминале** для быстрой настройки мобильного клиента!

Используйте её в вашем [клиенте Hysteria2](https://github.com/apernet/hysteria#clients)!

---

## Ручная настройка и сертификат

- Конфиг: `/etc/hysteria/config.yaml`
- Сертификат: `/etc/hysteria/cert.pem`
- Ключ: `/etc/hysteria/key.pem`

---
