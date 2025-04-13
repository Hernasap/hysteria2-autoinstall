#!/bin/bash

# ====================================
# AUTO-INSTALL HYSTERIA2 + DOMAIN + USER PANEL
# By ChatGPT | https://github.com/Hernasap
# ====================================

clear
echo "=== AUTO INSTALL HYSTERIA2 (with Domain + User Menu) ==="
read -rp "Masukkan domain yang akan digunakan (pastikan sudah mengarah ke IP VPS ini): " DOMAIN
read -rp "Masukkan password default akun (bisa diganti nanti): " PASSWORD

# Update sistem
apt update -y && apt upgrade -y
apt install curl wget socat cron bash openssl netcat -y

# Install acme.sh (untuk TLS Let's Encrypt)
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# Generate TLS cert
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --keylength ec-256 --force
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/hysteria/key.pem \
--fullchain-file /etc/hysteria/cert.pem

# Install Hysteria2
bash <(curl -fsSL https://get.hy2.sh/)

# Siapkan direktori dan config
mkdir -p /etc/hysteria/users
UUID=$(cat /proc/sys/kernel/random/uuid)

cat <<EOF > /etc/hysteria/config.yaml
listen: :443
tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem
auth:
  type: password
  password: $PASSWORD
masquerade:
  type: proxy
  proxy:
    url: https://$DOMAIN
    rewriteHost: true
EOF

# Buat service
cat <<EOF > /etc/systemd/system/hysteria2.service
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hysteria2
systemctl restart hysteria2

# Panel Manajemen User
cat <<'EOF' > /usr/bin/hysteria
#!/bin/bash

USER_DIR="/etc/hysteria/users"
CONFIG="/etc/hysteria/config.yaml"

function add_user() {
    read -rp "Masukkan nama user: " user
    read -rp "Berapa hari masa aktif: " days
    exp=$(date -d "+$days days" +%Y-%m-%d)
    echo "$user $exp" > "$USER_DIR/$user"
    echo "User $user ditambahkan, expired pada $exp"
}

function del_user() {
    read -rp "Masukkan nama user yang akan dihapus: " user
    rm -f "$USER_DIR/$user"
    echo "User $user dihapus."
}

function extend_user() {
    read -rp "Masukkan nama user: " user
    if [ ! -f "$USER_DIR/$user" ]; then
        echo "User tidak ditemukan!"
        exit 1
    fi
    read -rp "Tambah berapa hari: " days
    current=$(cut -d ' ' -f2 "$USER_DIR/$user")
    newexp=$(date -d "$current +$days days" +%Y-%m-%d)
    echo "$user $newexp" > "$USER_DIR/$user"
    echo "User $user diperpanjang hingga $newexp"
}

function list_user() {
    echo "Daftar User Aktif:"
    ls $USER_DIR | while read u; do
        info=$(cat $USER_DIR/$u)
        echo "- $info"
    done
}

case "$1" in
    add) add_user ;;
    del) del_user ;;
    extend) extend_user ;;
    list) list_user ;;
    *) echo "Usage: hysteria {add|del|extend|list}" ;;
esac
EOF

chmod +x /usr/bin/hysteria

echo ""
echo "=== INSTALLASI SELESAI ==="
echo "Domain     : $DOMAIN"
echo "Port       : 443 (UDP)"
echo "Password   : $PASSWORD"
echo "Menu user  : hysteria {add|del|extend|list}"


# === Pasang Menu User ===
cat <<'EOF' > /usr/bin/hysteria
#!/bin/bash

USER_DIR="/etc/hysteria/users"
CONFIG="/etc/hysteria/config.yaml"
DOMAIN=$(grep 'url:' $CONFIG | awk '{print $2}' | sed 's|https://||')

function add_user() {
    read -rp "Masukkan nama user: " user
    read -rp "Berapa hari masa aktif: " days
    exp=$(date -d "+$days days" +%Y-%m-%d)
    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo "$user $uuid $exp" > "$USER_DIR/$user"
    echo ""
    echo "User $user ditambahkan, expired pada $exp"
    echo ""
    echo "=== KONFIGURASI UNTUK V2RAYNG ==="
    echo "server: $DOMAIN:443"
    echo "auth: $uuid"
    echo "sni: static-web.prod.vidiocdn.com"
    echo "insecure: true"
    echo "fastOpen: true"
    echo ""
    echo "(Salin konfigurasi ini ke clipboard lalu tempel di V2RayNG)"
}

function del_user() {
    read -rp "Masukkan nama user yang akan dihapus: " user
    if [ -f "$USER_DIR/$user" ]; then
        rm -f "$USER_DIR/$user"
        echo "User $user dihapus."
    else
        echo "User tidak ditemukan!"
    fi
}

function extend_user() {
    read -rp "Masukkan nama user: " user
    if [ ! -f "$USER_DIR/$user" ]; then
        echo "User tidak ditemukan!"
        exit 1
    fi
    read -rp "Tambah berapa hari: " days
    line=$(cat "$USER_DIR/$user")
    uuid=$(echo $line | awk '{print $2}')
    current=$(echo $line | awk '{print $3}')
    newexp=$(date -d "$current +$days days" +%Y-%m-%d)
    echo "$user $uuid $newexp" > "$USER_DIR/$user"
    echo "User $user diperpanjang hingga $newexp"
}

function list_user() {
    echo "Daftar User Aktif:"
    for file in $USER_DIR/*; do
        line=$(cat "$file")
        user=$(basename "$file")
        uuid=$(echo $line | awk '{print $2}')
        exp=$(echo $line | awk '{print $3}')
        echo "- $user | Exp: $exp | Auth: $uuid"
    done
}

mkdir -p "$USER_DIR"

case "$1" in
    add) add_user ;;
    del) del_user ;;
    extend) extend_user ;;
    list) list_user ;;
    *) echo "Usage: hysteria {add|del|extend|list}" ;;
esac

EOF

chmod +x /usr/bin/hysteria
echo "Menu user berhasil dipasang: hysteria {add|del|extend|list}"
