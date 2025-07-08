# Hysteria2 Auto Install Script

**English | [Русский](#русский)**

---

## Fast Hysteria2 Installation (One Command)

Run this command on your VPS (Ubuntu/Debian):

```bash
curl -k -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && dos2unix /tmp/install-hysteria2.sh 2>/dev/null || sed -i 's/\r$//' /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && bash /tmp/install-hysteria2.sh
```

- Installs the latest [Hysteria2](https://github.com/apernet/hysteria) server
- Generates a secure random password and self-signed certificate
- Starts Hysteria2 on port 443 with password authentication
- Outputs ready-to-use hysteria2:// link for your client

**Default masquerade: [https://www.cloudflare.com/](https://www.cloudflare.com/)**

---

## Connection Example

After install, you will see a link like:

```
hysteria2://YOUR_PASSWORD@YOUR_IP:443/?insecure=1
```

Use this in your [Hysteria2 client](https://github.com/apernet/hysteria#clients)!

---

## Manual config and certificate

- Config path: `/etc/hysteria/config.yaml`
- Cert path: `/etc/hysteria/cert.pem`
- Key path: `/etc/hysteria/key.pem`

---

## Access to Local Network (LAN) in TUN Mode

If you use TUN mode (for example, with NekoBox or other Hysteria2 clients) and want access to your local devices (routers, printers, NAS, PCs), you must explicitly specify local IP ranges in the TUN settings in the “Bypass CIDR” field (or similar, such as “Direct List”).

**Recommended ranges to add:**
```
192.168.0.0/16
10.0.0.0/8
172.16.0.0/12
```

This allows your computer to communicate with local devices directly, bypassing the VPN tunnel. If you do not add these ranges, you may lose access to local addresses when TUN mode is enabled.

**Example settings in NekoBox:**

![image1](image1)

> **Note:**  
> Add these ranges to the “Bypass CIDR” list and ensure “Whitelist mode” is **disabled** if you want only local networks to bypass the VPN, with all other traffic going through the tunnel.

---

# Русский

## Быстрая установка Hysteria2 (одной командой)

Выполните на вашем сервере (Ubuntu/Debian):

```bash
curl -k -fsSL https://raw.githubusercontent.com/Kvilloks/Hysteria2-autoinstall/main/install-hysteria2.sh -o /tmp/install-hysteria2.sh && dos2unix /tmp/install-hysteria2.sh 2>/dev/null || sed -i 's/\r$//' /tmp/install-hysteria2.sh && chmod +x /tmp/install-hysteria2.sh && bash /tmp/install-hysteria2.sh
```

- Устанавливает последнюю версию [Hysteria2](https://github.com/apernet/hysteria)
- Генерирует пароль и самоподписанный сертификат
- Запускает сервер на порту 443 с авторизацией по паролю
- Показывает готовую ссылку hysteria2:// для клиента

**Маскарадинг по умолчанию: [https://www.cloudflare.com/](https://www.cloudflare.com/)**

---

## Пример подключения

После установки увидите ссылку:

```
hysteria2://ВАШ_ПАРОЛЬ@IP_СЕРВЕРА:443/?insecure=1
```

Используйте её в вашем [клиенте Hysteria2](https://github.com/apernet/hysteria#clients)!

---

## Ручная настройка и сертификат

- Конфиг: `/etc/hysteria/config.yaml`
- Сертификат: `/etc/hysteria/cert.pem`
- Ключ: `/etc/hysteria/key.pem`

---

## Доступ к локальной сети (LAN) в режиме TUN

Если вы используете режим TUN (например, с NekoBox или другими клиентами Hysteria2), чтобы обеспечить доступ к локальным устройствам (роутеры, принтеры, NAS, ПК в локалке), необходимо явно указать диапазоны локальных IP-адресов в настройках TUN в поле «Пропускать CIDR» (или аналогичном, например “Bypass CIDR”, “Direct List”).

**Рекомендуемые диапазоны для добавления:**
```
192.168.0.0/16
10.0.0.0/8
172.16.0.0/12
```

Это позволит компьютеру обращаться к локальным устройствам напрямую, минуя VPN-туннель. Если эти диапазоны не добавить, при активном TUN-режиме доступ к локальным адресам может быть потерян.

**Пример настройки в NekoBox:**

![image1](image1)

> **Важно:**  
> Включите эти диапазоны в список “Пропускать CIDR” и убедитесь, что “Режим белого списка” (Whitelist mode) ОТКЛЮЧЁН, если вы хотите пропускать только локальные сети напрямую, а весь остальной трафик отправлять через VPN.

---
