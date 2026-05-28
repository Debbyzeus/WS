#!/bin/bash
set -e
DOMAIN="a.debb1.me"
EMAIL="debbyzeus@gmail.com"
SSH_PORT="22"
WS_PORT="443"
echo "[1/5] Updating packages..."
apt update&&apt upgrade -y
apt install -y wget curl unzip socat openssh-server
echo "[2/5] Installing websocketd..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ];then
WS_URL="https://github.com/joewalnes/websocketd/releases/download/v0.4.1/websocketd-0.4.1-linux_amd64.zip"
elif [ "$ARCH" = "aarch64" ];then
WS_URL="https://github.com/joewalnes/websocketd/releases/download/v0.4.1/websocketd-0.4.1-linux_arm64.zip"
else
echo "Unsupported arch: $ARCH"
exit 1
fi
wget -O /tmp/websocketd.zip $WS_URL
unzip -o /tmp/websocketd.zip -d /usr/local/bin/
chmod +x /usr/local/bin/websocketd
rm /tmp/websocketd.zip
echo "[3/5] Setting up SSL with Certbot..."
if [ "$USE_SSL" = "true" ];then
apt install -y certbot
certbot certonly --standalone --agree-tos --non-interactive -m $EMAIL -d $DOMAIN
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo "0 3 * certbot renew --quiet --post-hook 'systemctl restart ssh-ws'" >/etc/cron.d/certbot-renew
fi
echo "[4/5] Creating systemd service..."
cat >/etc/systemd/system/ssh-ws.service <<EOF
[Unit]
Description=SSH over WebSocket
After=network.target
[Service]
ExecStart=/usr/local/bin/websocketd --port=$WS_PORT $(if [ "$USE_SSL" = "true" ];then echo "--ssl --sslcert=$CERT_PATH --sslkey=$KEY_PATH";fi) ssh localhost -p $SSH_PORT
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
echo "[5/5] Starting service..."
systemctl daemon-reload
systemctl enable ssh-ws
systemctl restart ssh-ws
ufw allow $WS_PORT/tcp||true
ufw allow ssh||true
echo ""
echo "========== DONE =========="
echo "Server running on $DOMAIN:$WS_PORT"
echo "Check status: systemctl status ssh-ws"
echo ""
echo "Client connect command:"
if [ "$USE_SSL" = "true" ];then
echo "websocat wss://$DOMAIN:$WS_PORT/ws - | ssh -e none user@localhost -p 22"
else
echo "websocat ws://$DOMAIN:$WS_PORT/ws - | ssh -e none user@localhost -p 22"
fi
