#!/bin/bash
clear
echo "==================================="
echo " HYSTERIA2 AUTO INSTALLER BY GPT  "
echo "==================================="
read -rp "Masukkan domain (pastikan sudah diarahkan ke IP VPS): " DOMAIN

# Install dependensi
apt update -y && apt install curl jq wget tar -y

# Install Hysteria2
curl -s https://get.hy2.sh | bash

# Buat direktori config
mkdir -p /etc/hysteria

# Generate sertifikat self-signed
openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/hysteria/key.pem -out /etc/hysteria/cert.pem -subj "/CN=${DOMAIN}" -days 365

# Buat config server
cat <<EOF > /etc/hysteria/config.yaml
listen: :443
tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem
auth:
  type: password
  password: gantipassworddefault
masquerade:
  type: proxy
  proxy:
    url: https://www.google.com
    rewriteHost: true
EOF

# Setup systemd
cat <<EOF > /etc/systemd/system/hysteria-server.service
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable hysteria-server
systemctl start hysteria-server

# Buat menu manajemen user
cat <<'EOF' > /usr/bin/hysteria-menu
#!/bin/bash

CONF_DIR="/etc/hysteria"
USER_DIR="$CONF_DIR/users"

mkdir -p "$USER_DIR"

function add_user() {
  read -rp "Username: " user
  pass=$(openssl rand -hex 8)
  echo "$pass" > "$USER_DIR/$user"
  cat <<EOL
=== KONFIGURASI CLIENT ===
server: $DOMAIN
port: 443
auth: $pass
tls: true
obfs: ""
EOL
}

function del_user() {
  read -rp "Username yang akan dihapus: " user
  rm -f "$USER_DIR/$user"
  echo "User $user dihapus."
}

function extend_user() {
  echo "Fitur extend belum diimplementasikan (manual ganti masa aktif)."
}

function list_user() {
  echo "Daftar user:"
  ls "$USER_DIR"
}

case "$1" in
  add) add_user ;;
  del) del_user ;;
  extend) extend_user ;;
  list) list_user ;;
  *) echo "Perintah: hysteria-menu {add|del|extend|list}" ;;
esac
EOF

chmod +x /usr/bin/hysteria-menu

echo ""
echo "=== INSTALASI SELESAI ==="
echo "Gunakan perintah 'hysteria-menu add' untuk tambah akun."
