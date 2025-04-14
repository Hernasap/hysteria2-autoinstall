#!/bin/bash

# === AUTO INSTALL HYSTERIA2 DENGAN MENU ===
# Port: 443
# Support: Tambah, Hapus, Perpanjang Akun

# Pastikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Jalankan sebagai root"
  exit
fi

# Input domain
read -p "Masukkan domain (pastikan sudah diarahkan ke IP VPS): " domain

# Install hysteria2
curl -s https://get.hy2.sh | bash

# Buat folder konfigurasi
mkdir -p /etc/hysteria /etc/hysteria/users

# Buat config server
cat <<EOF > /etc/hysteria/config.yaml
listen: :443
tls:
  cert: /etc/hysteria/fullchain.cer
  key: /etc/hysteria/private.key
auth:
  type: password
  password: gantipassworddefault
obfs:
  type: salamander
  password: obfspass
masquerade:
  type: proxy
  proxy:
    url: https://$domain
    rewriteHost: true
EOF

# Generate sertifikat TLS
openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/hysteria/private.key -out /etc/hysteria/fullchain.cer -days 365 \
-subj "/CN=$domain"

# Buat service systemd
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
systemctl enable hysteria-server
systemctl restart hysteria-server

# Pasang script menu
cat <<'MENU' > /usr/bin/hysteria
#!/bin/bash

data_path="/etc/hysteria/users"
domain=$(grep url /etc/hysteria/config.yaml | cut -d'/' -f3)
add_user() {
  read -p "Username: " user
  exp=$(date -d "+30 days" +%Y-%m-%d)
  pass=$(uuidgen)
  echo "$pass|$exp" > "$data_path/$user"

  cat <<EOF
=== HYSTERIA2 CONFIG ===
server: $domain:443
password: $pass
obfs-password: obfspass
alpn:
  - h3
insecure: true
fast-open: true
hop: []
=== END CONFIG ===
EOF
}

del_user() {
  read -p "Username: " user
  rm -f "$data_path/$user" && echo "User $user dihapus"
}

extend_user() {
  read -p "Username: " user
  if [ ! -f "$data_path/$user" ]; then
    echo "User tidak ditemukan!"
    exit 1
  fi
  oldpass=$(cut -d'|' -f1 "$data_path/$user")
  newexp=$(date -d "+30 days" +%Y-%m-%d)
  echo "$oldpass|$newexp" > "$data_path/$user"
  echo "User $user diperpanjang hingga $newexp"
}

list_user() {
  echo "==== LIST USER ===="
  for u in $data_path/*; do
    name=$(basename "$u")
    pass=$(cut -d'|' -f1 "$u")
    exp=$(cut -d'|' -f2 "$u")
    echo "$name | $pass | Exp: $exp"
  done
}

case "$1" in
  add) add_user ;;
  del) del_user ;;
  extend) extend_user ;;
  list) list_user ;;
  *) echo "Perintah: hysteria {add|del|extend|list}" ;;
esac
MENU

chmod +x /usr/bin/hysteria

echo "=== INSTALASI SELESAI ==="
echo "Gunakan perintah 'hysteria add' untuk menambah user"
