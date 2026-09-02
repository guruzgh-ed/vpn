#!/bin/bash
set -o pipefail

#by GuruzGH
clear

# Initializing Server
export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
  ubuntu:22.04) SUPPORT_LEVEL="recommended" ;;
  ubuntu:24.04) SUPPORT_LEVEL="supported" ;;
  debian:11) SUPPORT_LEVEL="legacy" ;;
  debian:12) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

echo "======================================================================="
echo "              Guruz GH SSH Script Installer"
echo "        (Multi-Protocol Edition: SSH/Xray/Hysteria/OpenVPN/ZiVPN/UDP Custom)"
echo "======================================================================="
echo ""
echo "Supported Operating Systems:"
echo ""
echo "  ✔ Debian 12              (Recommended)"
echo "  ✔ Debian 11              (Legacy Support)"
echo "  ✔ Ubuntu 24.04           (Supported)"
echo "  ✔ Ubuntu 22.04           (Recommended)"
echo "  ✔ Ubuntu 20.04           (Legacy Support)"
echo ""
echo "======================================================================="
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "This installer supports Ubuntu 20.04/22.04/24.04 and Debian 11/12 only."
  echo "Detected: ${ID} ${VERSION_ID}"
  exit 1
fi

#Script Variables
read -p "Enter your Domain/Subdomain for Xray (or press enter for IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN

is_ipv4_literal() {
  local IFS=. octet
  local -a parts
  read -r -a parts <<< "$1"
  [ "${#parts[@]}" -eq 4 ] || return 1
  for octet in "${parts[@]}"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] || return 1
    (( 10#$octet <= 255 )) || return 1
  done
}

is_dns_name() {
  [ "${#1}" -le 253 ] &&
    [[ "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]
}

DOMAIN_IS_IPV4=0
if is_ipv4_literal "$DOMAIN"; then
  DOMAIN_IS_IPV4=1
elif ! is_dns_name "$DOMAIN"; then
  echo "Invalid Xray domain/IP. Enter a DNS hostname or IPv4 address only."
  exit 1
fi
export DOMAIN

# OpenSSH Ports
SSH_Port1='22'
SSH_Port2='299'

# Dropbear Ports
Dropbear_Port1='790'
Dropbear_Port2='550'

# Stunnel Ports (Internal Fallback)
Stunnel_Port='127.0.0.1:4443'
Stunnel_Port_Num='4443' 

# Squid Ports
Squid_Port1='3128'
Squid_Port2='8000'

# Node.js Socks Proxy (Isolated Ports)
WsPorts=('10080' '2082' '2086')  
WsPort='10080'  

# SSLH Port
MainPort='666' 

# OpenVPN 3 compatible server entry points
# TunnelGuard/OpenVPN3 client core stays on Android; the VPS runs standard OpenVPN.
OPENVPN_TCP_PORT="1194"
OPENVPN_UDP_PORT="1194"
OPENVPN_TCP_BACKEND="11940"
OPENVPN_SSL_PORT="8443"
OPENVPN_PAYLOAD_PORT="8081"
OPENVPN_PROXY_PORT="3128"

# SSH SlowDNS
read -p "Enter SlowDNS Nameserver (or press enter for default): " -e -i "ns-dl.guruzgh.ovh" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

# UDP Variables (Hysteria, UDP Custom, ZiVPN)
UDP_PORT=":36712"
HYST2_PORT="36713"
UDP_CUSTOM_PORT="36717"
ZIVPN_PORT="5667"
_default_obfs='GuruzScript'
_default_password='GuruzScript'

if [ -t 0 ]; then
  read -e -p "Enter Hysteria/ZiVPN obfuscation string (obfs) [${_default_obfs}]: " -i "${_default_obfs}" _input_obfs
  OBFS="${_input_obfs:-${_default_obfs}}"
  read -e -p "Enter UDP Default password [${_default_password}]: " -i "${_default_password}" _input_pass
  PASSWORD="${_input_pass:-${_default_password}}"
else
  OBFS="${OBFS:-${_default_obfs}}"
  PASSWORD="${PASSWORD:-${_default_password}}"
fi

export OBFS PASSWORD

# WebServer Ports
Nginx_Port='85' 

# DNS Resolver cloudflare dns
Dns_1='1.1.1.1' 
Dns_2='1.0.0.1'

# Server local time
MyVPS_Time='Africa/Accra'

# Telegram IDs
# Optional Telegram health notifications. Never embed reusable bot credentials.
My_Chat_ID="${TELEGRAM_CHAT_ID:-}"
My_Bot_Key="${TELEGRAM_BOT_TOKEN:-}"
if [ -t 0 ] && [ -z "$My_Bot_Key" ]; then
  read -r -p "Telegram bot token for health alerts (optional; press enter to disable): " My_Bot_Key
  if [ -n "$My_Bot_Key" ]; then
    read -r -p "Telegram chat ID: " My_Chat_ID
  fi
fi

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

red='\e[1;31m'; green='\e[0;32m'; NC='\e[0m'

apt-get update -y && apt-get upgrade -y --with-new-pkgs

systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

SSH_SERVICE="ssh"; DROPBEAR_SERVICE="dropbear"; STUNNEL_SERVICE="stunnel4"; SQUID_SERVICE="squid"; SSLH_SERVICE="sslh"; NGINX_SERVICE="nginx"; HAPROXY_SERVICE="haproxy"; SFTP_SUBSYSTEM="internal-sftp"

mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
ssh-keygen -A >/dev/null 2>&1 || true

command -v ss >/dev/null 2>&1 || apt-get install -y iproute2
command -v netfilter-persistent >/dev/null 2>&1 || apt-get install -y netfilter-persistent iptables-persistent
command -v jq >/dev/null 2>&1 || apt-get install -y jq
command -v curl >/dev/null 2>&1 || apt-get install -y curl

if ! systemctl list-unit-files | grep -q "^${STUNNEL_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^stunnel\.service"; then STUNNEL_SERVICE="stunnel"; fi
fi
if ! systemctl list-unit-files | grep -q "^${SQUID_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^squid3\.service"; then SQUID_SERVICE="squid3"; fi
fi

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar zip gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx haproxy certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat openssl openvpn easy-rsa python3
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then AVAILABLE_PACKAGES+=("$pkg"); fi
done

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

cat > /root/.profile <<'EOF_PROFILE'
clear
echo "Script By Guruz GH"
echo "Type 'menu' To List Commands"
EOF_PROFILE

apt-get install -y "${AVAILABLE_PACKAGES[@]}"

if command -v dropbearkey >/dev/null 2>&1; then
  [ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  [ -f /etc/dropbear/dropbear_dss_host_key ] || dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
  [ -f /etc/dropbear/dropbear_ecdsa_host_key ] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
fi

systemctl enable "$SSH_SERVICE" || true
systemctl enable rsyslog || true
systemctl restart rsyslog || true
gem install lolcat
apt -y --purge remove apache2 ufw firewalld
systemctl stop nginx

wget -q https://github.com/webmin/webmin/releases/download/2.111/webmin_2.111_all.deb
dpkg --install webmin_2.111_all.deb || apt-get install -f -y
rm -rf webmin_2.111_all.deb
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf
systemctl restart webmin || true

# === UNIQUE TLS CERTIFICATE FOR XRAY, HAPROXY & STUNNEL ===
# Prefer a trusted ACME certificate when the hostname already points here.
# IP installs and failed ACME attempts receive a unique per-install certificate.
echo "Provisioning a unique SSL certificate for Xray & Stunnel..."
XRAY_TLS_ALLOW_INSECURE="1"
XRAY_CERT_SOURCE="self-signed"
rm -f /etc/xray/xray.key /etc/xray/xray.crt

if [ "$DOMAIN_IS_IPV4" -eq 0 ] && [ -n "$IPADDR" ] && \
   getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u | grep -Fxq "$IPADDR"; then
  systemctl stop xray 2>/dev/null || true
  if certbot certonly --standalone --non-interactive --agree-tos \
      --register-unsafely-without-email --preferred-challenges http \
      --keep-until-expiring -d "$DOMAIN"; then
    install -m 600 "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key
    install -m 644 "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt
    XRAY_TLS_ALLOW_INSECURE="0"
    XRAY_CERT_SOURCE="letsencrypt"
  fi
fi

if [ ! -s /etc/xray/xray.key ] || [ ! -s /etc/xray/xray.crt ]; then
  if [ "$DOMAIN_IS_IPV4" -eq 1 ]; then
    XRAY_CERT_SAN="IP:$DOMAIN"
  else
    XRAY_CERT_SAN="DNS:$DOMAIN"
  fi
  if ! openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 825 \
    -subj "/CN=$DOMAIN" -addext "subjectAltName=$XRAY_CERT_SAN" \
    -keyout /etc/xray/xray.key -out /etc/xray/xray.crt; then
    echo "Unable to generate the fallback TLS certificate."
    exit 1
  fi
fi

chmod 600 /etc/xray/xray.key
chmod 644 /etc/xray/xray.crt

# Copy and secure Stunnel cert
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem; chown root:root /etc/stunnel/stunnel.pem

if [ "$XRAY_CERT_SOURCE" = "letsencrypt" ]; then
  mkdir -p /etc/letsencrypt/renewal-hooks/pre /etc/letsencrypt/renewal-hooks/deploy /etc/letsencrypt/renewal-hooks/post
  cat <<'EOF_XRAY_CERT_PRE' > /etc/letsencrypt/renewal-hooks/pre/xray-stop.sh
#!/bin/bash
systemctl stop xray 2>/dev/null || true
EOF_XRAY_CERT_PRE
  cat <<'EOF_XRAY_CERT_RENEW' > /etc/letsencrypt/renewal-hooks/deploy/xray-cert.sh
#!/bin/bash
set -e
umask 077
install -m 600 "$RENEWED_LINEAGE/privkey.pem" /etc/xray/xray.key
install -m 644 "$RENEWED_LINEAGE/fullchain.pem" /etc/xray/xray.crt
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem.new
install -m 600 /etc/stunnel/stunnel.pem.new /etc/stunnel/stunnel.pem
rm -f /etc/stunnel/stunnel.pem.new
systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel
systemctl restart hysteria2-server 2>/dev/null || true
EOF_XRAY_CERT_RENEW
  cat <<'EOF_XRAY_CERT_POST' > /etc/letsencrypt/renewal-hooks/post/xray-start.sh
#!/bin/bash
systemctl start xray 2>/dev/null || true
EOF_XRAY_CERT_POST
  chmod 700 /etc/letsencrypt/renewal-hooks/pre/xray-stop.sh \
    /etc/letsencrypt/renewal-hooks/deploy/xray-cert.sh \
    /etc/letsencrypt/renewal-hooks/post/xray-start.sh
fi

cat <<'deekay77' > /etc/zorro-luffy
<br><font color="#C12267">GURUZGH | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x No DDOS<br></font>
<font color="#00cc00"> x No Torrent<br></font>
<font color="#ff1aff"> x No Spamming<br></font>
<font color="blue"> x No Phishing<br></font>
<font color="#A810FF"> x No Hacking<br></font><br>
<font color="red">• BROUGHT TO YOU BY <br></font><font color="#00cccc">https://t.me/guruzfreenet !<br></font>
deekay77

# OpenSSH
rm -f /etc/ssh/sshd_config
cat <<'MySSHConfig' > /etc/ssh/sshd_config
Port myPORT1
Port myPORT2
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 5000
MaxStartups 500:30:1000
LoginGraceTime 30
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no
Banner /etc/zorro-luffy
LogLevel QUIET
AcceptEnv LANG LC_*
Subsystem sftp SFTP_SUBSYSTEM
MySSHConfig

sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config
sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config
sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config
sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
sed -i 's/use_authtok //g' /etc/pam.d/common-password
sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE"

# Dropbear
rm -rf /etc/default/dropbear*
cat <<'MyDropbear' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=PORT01
DROPBEAR_EXTRA_ARGS="-p PORT02"
DROPBEAR_BANNER="/etc/zorro-luffy"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
MyDropbear
sed -i "s|PORT01|$Dropbear_Port1|g" /etc/default/dropbear
sed -i "s|PORT02|$Dropbear_Port2|g" /etc/default/dropbear
systemctl restart "$DROPBEAR_SERVICE"

# SSLH
cd /etc/default/
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$Dropbear_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
systemctl daemon-reload; systemctl enable "$SSLH_SERVICE"; systemctl restart "$SSLH_SERVICE"
cd

# Stunnel
StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/zorro-luffy"
PPP_RESTART=0
RLIMITS=""
MyStunnelD

cat <<'MyStunnelC' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
syslog = no
debug = 0
output = /dev/null
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0
[sslh]
accept = Stunnel_Port
connect = 127.0.0.1:MainPort
MyStunnelC

sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf
systemctl enable "$STUNNEL_SERVICE"; systemctl restart "$STUNNEL_SERVICE"

# Node.js Socks Proxy (Isolated Multi-Process)
loc=/etc/socksproxy; mkdir -p $loc; apt-get install -y nodejs

cat <<EOF > $loc/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { console.error('Unhandled Exception:', err); });

const TARGET_HOST = '127.0.0.1'; 
const TARGET_PORT = $Dropbear_Port1;
const LISTEN_PORT = parseInt(process.argv[2]);
if (!LISTEN_PORT) { process.exit(1); }

const handleConnection = (clientSocket) => {
    let targetSocket = null;
    let responseSent = false;
    let sshBridged = false;
    let buffer = '';

    const onClientData = (data) => {
        if (sshBridged) return; // Connection is already piped to Dropbear

        buffer += data.toString('utf8');

        // 1. Determine and send the correct HTTP response dynamically
        if (!responseSent && buffer.length > 5) {
            responseSent = true;
            const isConnect = buffer.toUpperCase().startsWith('CONNECT');
            
            if (isConnect) {
                clientSocket.write('HTTP/1.1 200 OK\r\n\r\n');
            } else {
                clientSocket.write(
                    'HTTP/1.1 101 Switching Protocols\r\n' +
                    'Upgrade: websocket\r\n' +
                    'Connection: Upgrade\r\n\r\n'
                );
            }
        }

        // 2. Scan for the SSH handshake and violently strip the payload junk
        const sshIndex = buffer.indexOf('SSH-');
        if (sshIndex !== -1) {
            sshBridged = true;
            clientSocket.removeListener('data', onClientData);

            targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
                // Extract ONLY the clean SSH data and discard everything before it
                const cleanSshData = buffer.substring(sshIndex);
                targetSocket.write(Buffer.from(cleanSshData, 'utf8'));
                
                // Bridge the connections
                clientSocket.pipe(targetSocket);
                targetSocket.pipe(clientSocket);
            });

            targetSocket.on('error', () => clientSocket.destroy());
            targetSocket.on('close', () => clientSocket.destroy());
        }
    };

    clientSocket.on('data', onClientData);
    clientSocket.on('error', () => {});
    clientSocket.on('close', () => {
        if (targetSocket) targetSocket.destroy();
    });
};

const server = net.createServer(handleConnection);
server.listen(LISTEN_PORT, '0.0.0.0', () => { 
    console.log(\`WS Proxy active on isolated port \${LISTEN_PORT}\`); 
});
EOF

cat <<'service' > /etc/systemd/system/ws-proxy@.service
[Unit]
Description=Node.js WebSocket Proxy on port %i
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/socksproxy
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
LimitNOFILE=1048576
Restart=always
RestartSec=1
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js %i
SyslogIdentifier=ws-proxy-%i
[Install]
WantedBy=multi-user.target
service

systemctl daemon-reload
for port in "${WsPorts[@]}"; do systemctl enable ws-proxy@$port; systemctl restart ws-proxy@$port; done

# === OPENVPN SERVER FOR TUNNELGUARD OPENVPN3 ===
echo "Installing OpenVPN server for TunnelGuard/OpenVPN3..."
if ! command -v openvpn >/dev/null 2>&1 || [ ! -x /usr/share/easy-rsa/easyrsa ] || ! command -v python3 >/dev/null 2>&1; then
  if [ "${ID:-}" = "ubuntu" ] && ! apt-cache show easy-rsa >/dev/null 2>&1; then
    add-apt-repository -y universe >/dev/null 2>&1 || true
    apt-get update -y
  fi
  apt-get install -y openvpn easy-rsa python3 || { echo "Unable to install OpenVPN dependencies."; exit 1; }
fi
[ -x /usr/share/easy-rsa/easyrsa ] || { echo "Easy-RSA is not available on this system."; exit 1; }
mkdir -p /etc/openvpn/server /etc/openvpn/easy-rsa /etc/openvpn/clients /usr/local/libexec /run/openvpn
chmod 700 /etc/openvpn/clients

# Build an OpenVPN-only PKI. The Xray certificate is used only for the outer
# Stunnel transport on OPENVPN_SSL_PORT; OpenVPN's own TLS identity is separate.
if [ ! -x /etc/openvpn/easy-rsa/easyrsa ]; then
  cp -a /usr/share/easy-rsa/. /etc/openvpn/easy-rsa/
fi
if [ ! -s /etc/openvpn/easy-rsa/pki/ca.crt ] || \
   [ ! -s /etc/openvpn/easy-rsa/pki/issued/server.crt ] || \
   [ ! -s /etc/openvpn/easy-rsa/pki/private/server.key ]; then
  (
    cd /etc/openvpn/easy-rsa || exit 1
    EASYRSA_BATCH=1 ./easyrsa init-pki
    EASYRSA_BATCH=1 EASYRSA_REQ_CN="GuruzGH OpenVPN CA" EASYRSA_CA_EXPIRE=3650 ./easyrsa build-ca nopass
    EASYRSA_BATCH=1 EASYRSA_CERT_EXPIRE=1825 ./easyrsa build-server-full server nopass
  ) || { echo "OpenVPN PKI generation failed."; exit 1; }
fi
chmod 600 /etc/openvpn/easy-rsa/pki/private/server.key
chmod 644 /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/easy-rsa/pki/issued/server.crt

if [ ! -s /etc/openvpn/tls-crypt.key ]; then
  /usr/sbin/openvpn --genkey secret /etc/openvpn/tls-crypt.key || {
    echo "Unable to generate OpenVPN tls-crypt key."; exit 1;
  }
fi
chmod 600 /etc/openvpn/tls-crypt.key

# Standalone OpenVPN account database. Passwords are verified using PBKDF2.
# A root-only secrets file is also maintained so the menu can re-display the
# credentials needed by the VPN generator.
cat <<'EOF_OVPN_USERCTL' > /usr/local/libexec/openvpn-userctl
#!/usr/bin/env python3
import base64
import datetime as dt
import hashlib
import hmac
import os
import re
import secrets
import sys

DB = "/etc/openvpn/users.db"
SECRETS = "/etc/openvpn/users.secrets"
ITERATIONS = 240_000
USER_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def today():
    return dt.date.today()


def parse_date(value):
    return dt.date.fromisoformat(value)


def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return [line.rstrip("\n") for line in f if line.strip()]
    except FileNotFoundError:
        return []


def atomic_write(path, lines):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")
        f.flush()
        os.fsync(f.fileno())
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def make_hash(password, salt_hex=None):
    salt = bytes.fromhex(salt_hex) if salt_hex else secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
    return salt.hex(), digest.hex()


def db_records():
    result = {}
    for line in read_lines(DB):
        parts = line.split("|", 3)
        if len(parts) == 4:
            result[parts[0]] = parts
    return result


def secret_records():
    result = {}
    for line in read_lines(SECRETS):
        parts = line.split("|", 2)
        if len(parts) == 3:
            result[parts[0]] = parts
    return result


def save(db, sec):
    atomic_write(DB, ["|".join(db[k]) for k in sorted(db)])
    atomic_write(SECRETS, ["|".join(sec[k]) for k in sorted(sec)])


def valid_user(user):
    return bool(USER_RE.fullmatch(user)) and user not in (".", "..")


def cmd_add(user, password, expiry):
    if not valid_user(user) or not password:
        return 2
    parse_date(expiry)
    db, sec = db_records(), secret_records()
    if user in db:
        return 3
    salt, digest = make_hash(password)
    db[user] = [user, salt, digest, expiry]
    sec[user] = [user, base64.b64encode(password.encode()).decode(), expiry]
    save(db, sec)
    return 0


def cmd_passwd(user, password):
    if not password:
        return 2
    db, sec = db_records(), secret_records()
    if user not in db:
        return 3
    salt, digest = make_hash(password)
    expiry = db[user][3]
    db[user] = [user, salt, digest, expiry]
    sec[user] = [user, base64.b64encode(password.encode()).decode(), expiry]
    save(db, sec)
    return 0


def cmd_renew(user, expiry):
    parse_date(expiry)
    db, sec = db_records(), secret_records()
    if user not in db:
        return 3
    db[user][3] = expiry
    if user in sec:
        sec[user][2] = expiry
    save(db, sec)
    return 0


def cmd_delete(user):
    db, sec = db_records(), secret_records()
    if user not in db:
        return 3
    db.pop(user, None)
    sec.pop(user, None)
    save(db, sec)
    return 0


def cmd_cleanup():
    db, sec = db_records(), secret_records()
    keep = {u: r for u, r in db.items() if parse_date(r[3]) >= today()}
    keep_sec = {u: r for u, r in sec.items() if u in keep}
    save(keep, keep_sec)
    return 0


def cmd_list():
    for user, record in sorted(db_records().items()):
        print(f"{user} {record[3]}")
    return 0


def cmd_secret(user):
    record = secret_records().get(user)
    if not record:
        return 3
    try:
        print(base64.b64decode(record[1]).decode("utf-8"))
    except Exception:
        return 4
    return 0


def cmd_verify(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            username = f.readline().rstrip("\r\n")
            password = f.readline().rstrip("\r\n")
    except Exception:
        return 1
    record = db_records().get(username)
    if not record or not password:
        return 1
    try:
        if parse_date(record[3]) < today():
            return 1
        salt = bytes.fromhex(record[1])
        expected = bytes.fromhex(record[2])
        actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, ITERATIONS)
        return 0 if hmac.compare_digest(actual, expected) else 1
    except Exception:
        return 1


def main():
    if len(sys.argv) < 2:
        return 2
    cmd = sys.argv[1]
    try:
        if cmd == "add" and len(sys.argv) == 5:
            return cmd_add(sys.argv[2], sys.argv[3], sys.argv[4])
        if cmd == "passwd" and len(sys.argv) == 4:
            return cmd_passwd(sys.argv[2], sys.argv[3])
        if cmd == "renew" and len(sys.argv) == 4:
            return cmd_renew(sys.argv[2], sys.argv[3])
        if cmd == "delete" and len(sys.argv) == 3:
            return cmd_delete(sys.argv[2])
        if cmd == "cleanup" and len(sys.argv) == 2:
            return cmd_cleanup()
        if cmd == "list" and len(sys.argv) == 2:
            return cmd_list()
        if cmd == "secret" and len(sys.argv) == 3:
            return cmd_secret(sys.argv[2])
        if cmd == "verify" and len(sys.argv) == 3:
            return cmd_verify(sys.argv[2])
    except Exception:
        return 2
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
EOF_OVPN_USERCTL
chmod 700 /usr/local/libexec/openvpn-userctl
[ -f /etc/openvpn/users.db ] || : > /etc/openvpn/users.db
[ -f /etc/openvpn/users.secrets ] || : > /etc/openvpn/users.secrets
chmod 600 /etc/openvpn/users.db /etc/openvpn/users.secrets

cat <<'EOF_OVPN_AUTH' > /usr/local/libexec/openvpn-auth
#!/bin/sh
[ -n "$1" ] || exit 1
exec /usr/local/libexec/openvpn-userctl verify "$1"
EOF_OVPN_AUTH
chmod 700 /usr/local/libexec/openvpn-auth

# OpenVPN TCP backend is loopback-only. Public TCP enters through the smart
# gateway so raw TCP and TunnelGuard payload modes can share port 1194.
cat > /etc/openvpn/server/tcp.conf <<EOF_OVPN_TCP
local 127.0.0.1
port $OPENVPN_TCP_BACKEND
proto tcp-server
dev tun-ovpn-tcp

ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh none
tls-crypt /etc/openvpn/tls-crypt.key
tls-version-min 1.2

verify-client-cert none
username-as-common-name
auth-user-pass-verify /usr/local/libexec/openvpn-auth via-file
script-security 2
tmp-dir /dev/shm

server 10.8.0.0 255.255.255.0
topology subnet
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $Dns_1"
push "dhcp-option DNS $Dns_2"

keepalive 10 120
persist-key
persist-tun
status /run/openvpn/tcp-status.log 10
status-version 3
verb 3
EOF_OVPN_TCP

# Native UDP OpenVPN3 path.
cat > /etc/openvpn/server/udp.conf <<EOF_OVPN_UDP
port $OPENVPN_UDP_PORT
proto udp
dev tun-ovpn-udp

ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh none
tls-crypt /etc/openvpn/tls-crypt.key
tls-version-min 1.2

verify-client-cert none
username-as-common-name
auth-user-pass-verify /usr/local/libexec/openvpn-auth via-file
script-security 2
tmp-dir /dev/shm

server 10.9.0.0 255.255.255.0
topology subnet
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $Dns_1"
push "dhcp-option DNS $Dns_2"

keepalive 10 120
persist-key
persist-tun
explicit-exit-notify 1
status /run/openvpn/udp-status.log 10
status-version 3
verb 3
EOF_OVPN_UDP
chmod 600 /etc/openvpn/server/tcp.conf /etc/openvpn/server/udp.conf

# Smart TCP gateway: raw OpenVPN is forwarded untouched. HTTP-like TunnelGuard
# payload headers are silently removed before the first OpenVPN packet reaches
# the private TCP backend. No HTTP response is sent to the Android side.
cat <<'EOF_OVPN_GATEWAY' > /etc/openvpn/openvpn-gateway.js
'use strict';
const net = require('net');

const BACKEND_HOST = '127.0.0.1';
const BACKEND_PORT = Number(process.env.OPENVPN_BACKEND || '11940');
const LISTEN_PORTS = (process.env.OPENVPN_LISTEN_PORTS || '1194,8081')
  .split(',').map(v => Number(v.trim())).filter(Boolean);
const MAX_HEADER = 65536;
const DECISION_TIMEOUT_MS = 5000;
const CONNECT_TIMEOUT_MS = 15000;
const METHODS = ['GET ', 'POST ', 'CONNECT ', 'HEAD ', 'PUT ', 'OPTIONS ', 'PATCH ', 'DELETE ', 'TRACE '];

function payloadPrefix(buffer) {
  const text = buffer.slice(0, Math.min(buffer.length, 16)).toString('latin1').toUpperCase();
  return METHODS.some(m => m.startsWith(text) || text.startsWith(m));
}

function headerEnd(buffer) {
  let pos = buffer.indexOf(Buffer.from('\r\n\r\n', 'latin1'));
  if (pos >= 0) return pos + 4;
  pos = buffer.indexOf(Buffer.from('\n\n', 'latin1'));
  return pos >= 0 ? pos + 2 : -1;
}

function bridge(client, initial) {
  client.pause();
  const upstream = net.connect({host: BACKEND_HOST, port: BACKEND_PORT});
  let timer = setTimeout(() => upstream.destroy(new Error('backend connect timeout')), CONNECT_TIMEOUT_MS);
  upstream.once('connect', () => {
    clearTimeout(timer);
    timer = null;
    if (initial && initial.length) upstream.write(initial);
    client.pipe(upstream);
    upstream.pipe(client);
    client.resume();
  });
  const close = () => {
    try { client.destroy(); } catch (_) {}
    try { upstream.destroy(); } catch (_) {}
  };
  client.on('error', close);
  upstream.on('error', close);
  client.on('close', () => { try { upstream.destroy(); } catch (_) {} });
  upstream.on('close', () => { try { client.destroy(); } catch (_) {} });
}

function handle(client) {
  client.setNoDelay(true);
  let buffer = Buffer.alloc(0);
  let decided = false;
  const timer = setTimeout(() => {
    if (!decided) client.destroy();
  }, DECISION_TIMEOUT_MS);

  function decideRaw() {
    if (decided) return;
    decided = true;
    clearTimeout(timer);
    client.removeListener('data', onFirstData);
    bridge(client, buffer);
  }

  function onFirstData(chunk) {
    if (decided) return;
    buffer = Buffer.concat([buffer, chunk]);
    if (buffer.length > MAX_HEADER) return client.destroy();

    // OpenVPN TCP starts as binary. If the first bytes cannot be an HTTP-style
    // payload method, forward immediately and preserve every byte.
    if (!payloadPrefix(buffer)) return decideRaw();

    const end = headerEnd(buffer);
    if (end >= 0) {
      decided = true;
      clearTimeout(timer);
      client.removeListener('data', onFirstData);
      bridge(client, buffer.slice(end)); // silently discard injected payload
    }
  }

  client.on('data', onFirstData);
  client.on('error', () => {});
}

for (const port of LISTEN_PORTS) {
  const server = net.createServer(handle);
  server.on('error', err => {
    console.error(`OpenVPN gateway ${port}: ${err.message}`);
    process.exitCode = 1;
  });
  server.listen(port, '0.0.0.0', () => console.log(`OpenVPN gateway listening on ${port}`));
}
EOF_OVPN_GATEWAY
chmod 644 /etc/openvpn/openvpn-gateway.js

cat <<EOF_OVPN_TCP_SERVICE > /etc/systemd/system/openvpn-tcp.service
[Unit]
Description=GuruzGH OpenVPN TCP Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStartPre=/bin/mkdir -p /run/openvpn
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/server/tcp.conf
Restart=on-failure
RestartSec=2
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF_OVPN_TCP_SERVICE

cat <<EOF_OVPN_UDP_SERVICE > /etc/systemd/system/openvpn-udp.service
[Unit]
Description=GuruzGH OpenVPN UDP Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStartPre=/bin/mkdir -p /run/openvpn
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/server/udp.conf
Restart=on-failure
RestartSec=2
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF_OVPN_UDP_SERVICE

cat <<EOF_OVPN_GATEWAY_SERVICE > /etc/systemd/system/openvpn-gateway.service
[Unit]
Description=GuruzGH OpenVPN Raw/Payload Gateway
After=network-online.target openvpn-tcp.service
Wants=network-online.target openvpn-tcp.service

[Service]
Type=simple
User=nobody
Group=nogroup
Environment=OPENVPN_BACKEND=$OPENVPN_TCP_BACKEND
Environment=OPENVPN_LISTEN_PORTS=$OPENVPN_TCP_PORT,$OPENVPN_PAYLOAD_PORT
ExecStart=/usr/bin/node /etc/openvpn/openvpn-gateway.js
Restart=always
RestartSec=1
NoNewPrivileges=true
PrivateTmp=true
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF_OVPN_GATEWAY_SERVICE

# Persistent forwarding/NAT lifecycle for both OpenVPN address pools.
cat <<EOF_OVPN_NAT > /usr/local/libexec/openvpn-nat
#!/bin/bash
set -u
ACTION="\${1:-start}"
IFACE="\$(ip -4 route show default | awk '/default/ {print \$5; exit}')"
[ -n "\$IFACE" ] || exit 1
TCP_NET="10.8.0.0/24"
UDP_NET="10.9.0.0/24"
TCP_PORT="$OPENVPN_TCP_PORT"
UDP_PORT="$OPENVPN_UDP_PORT"
PAYLOAD_PORT="$OPENVPN_PAYLOAD_PORT"
SSL_PORT="$OPENVPN_SSL_PORT"

add_rule() { iptables -C "\$@" 2>/dev/null || iptables -I "\$@"; }
del_rule() { while iptables -C "\$@" 2>/dev/null; do iptables -D "\$@" || break; done; }
add_nat() { iptables -t nat -C "\$@" 2>/dev/null || iptables -t nat -A "\$@"; }
del_nat() { while iptables -t nat -C "\$@" 2>/dev/null; do iptables -t nat -D "\$@" || break; done; }

if [ "\$ACTION" = "start" ]; then
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  add_rule INPUT -p tcp --dport "\$TCP_PORT" -j ACCEPT
  add_rule INPUT -p udp --dport "\$UDP_PORT" -j ACCEPT
  add_rule INPUT -p tcp --dport "\$PAYLOAD_PORT" -j ACCEPT
  add_rule INPUT -p tcp --dport "\$SSL_PORT" -j ACCEPT
  add_rule FORWARD -s "\$TCP_NET" -j ACCEPT
  add_rule FORWARD -d "\$TCP_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  add_rule FORWARD -s "\$UDP_NET" -j ACCEPT
  add_rule FORWARD -d "\$UDP_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  add_nat POSTROUTING -s "\$TCP_NET" -o "\$IFACE" -j MASQUERADE
  add_nat POSTROUTING -s "\$UDP_NET" -o "\$IFACE" -j MASQUERADE
  exit 0
fi

if [ "\$ACTION" = "stop" ]; then
  del_rule INPUT -p tcp --dport "\$TCP_PORT" -j ACCEPT
  del_rule INPUT -p udp --dport "\$UDP_PORT" -j ACCEPT
  del_rule INPUT -p tcp --dport "\$PAYLOAD_PORT" -j ACCEPT
  del_rule INPUT -p tcp --dport "\$SSL_PORT" -j ACCEPT
  del_rule FORWARD -s "\$TCP_NET" -j ACCEPT
  del_rule FORWARD -d "\$TCP_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  del_rule FORWARD -s "\$UDP_NET" -j ACCEPT
  del_rule FORWARD -d "\$UDP_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  del_nat POSTROUTING -s "\$TCP_NET" -o "\$IFACE" -j MASQUERADE
  del_nat POSTROUTING -s "\$UDP_NET" -o "\$IFACE" -j MASQUERADE
  exit 0
fi
exit 2
EOF_OVPN_NAT
chmod 700 /usr/local/libexec/openvpn-nat

cat <<'EOF_OVPN_NAT_SERVICE' > /etc/systemd/system/openvpn-nat.service
[Unit]
Description=GuruzGH OpenVPN NAT/Forwarding Rules
After=network-online.target
Wants=network-online.target
Before=openvpn-tcp.service openvpn-udp.service openvpn-gateway.service

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/openvpn-nat start
ExecStop=/usr/local/libexec/openvpn-nat stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_OVPN_NAT_SERVICE

# Add a dedicated outer TLS listener for TunnelGuard's SSL OpenVPN modes.
if ! grep -q '^\[openvpn-tunnelguard\]$' /etc/stunnel/stunnel.conf; then
  cat <<EOF_OVPN_STUNNEL >> /etc/stunnel/stunnel.conf

[openvpn-tunnelguard]
accept = 0.0.0.0:$OPENVPN_SSL_PORT
connect = 127.0.0.1:$OPENVPN_TCP_PORT
TIMEOUTclose = 0
EOF_OVPN_STUNNEL
fi

# One reusable OpenVPN profile per VPS. TunnelGuard supplies the standalone
# username/password separately and overrides host/port/proto for each tweak.
cat > /etc/openvpn/client-template.ovpn <<EOF_OVPN_PROFILE
client
dev tun
proto tcp-client
remote $DOMAIN $OPENVPN_TCP_PORT
nobind
persist-key
persist-tun
remote-cert-tls server
tls-version-min 1.2
auth-user-pass
auth-nocache
connect-retry 2
connect-retry-max 5
resolv-retry infinite
verb 3

<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<tls-crypt>
$(cat /etc/openvpn/tls-crypt.key)
</tls-crypt>
EOF_OVPN_PROFILE
chmod 600 /etc/openvpn/client-template.ovpn

# Expired standalone users are removed daily; no OpenVPN service restart is needed.
cat <<'EOF_OVPN_EXP' > /etc/cron.d/openvpn-expiry
7 0 * * * root /usr/local/libexec/openvpn-userctl cleanup >/dev/null 2>&1
EOF_OVPN_EXP
chmod 644 /etc/cron.d/openvpn-expiry

systemctl daemon-reload
systemctl enable openvpn-nat.service openvpn-tcp.service openvpn-udp.service openvpn-gateway.service
systemctl restart openvpn-nat.service
systemctl restart openvpn-tcp.service
systemctl restart openvpn-udp.service
systemctl restart openvpn-gateway.service
systemctl restart "$STUNNEL_SERVICE"

# Fail installation early if the core OpenVPN listeners did not come up.
sleep 1
if ! systemctl is-active --quiet openvpn-tcp.service || \
   ! systemctl is-active --quiet openvpn-udp.service || \
   ! systemctl is-active --quiet openvpn-gateway.service; then
  journalctl -u openvpn-tcp -u openvpn-udp -u openvpn-gateway -n 80 --no-pager
  echo "OpenVPN stack failed to start."
  exit 1
fi

# === XRAY CORE ===
echo "Installing Hiddify-aligned stable Xray Core v26.3.27..."
XRAY_VER="v26.3.27"

cat <<'EOF_XRAY_INSTALLER' > /usr/local/sbin/xray-install-version
#!/bin/bash
set -o pipefail
umask 077

version="${1:?Usage: xray-install-version VERSION}"
case "$(uname -m)" in
  x86_64|amd64) asset="Xray-linux-64.zip" ;;
  i386|i486|i586|i686) asset="Xray-linux-32.zip" ;;
  aarch64|arm64) asset="Xray-linux-arm64-v8a.zip" ;;
  armv7l|armv7*) asset="Xray-linux-arm32-v7a.zip" ;;
  *) echo "Unsupported Xray architecture: $(uname -m)" >&2; exit 1 ;;
esac

tmp_dir=$(mktemp -d /tmp/xray-install.XXXXXX) || exit 1
trap 'rm -rf "$tmp_dir"' EXIT
base_url="https://github.com/XTLS/Xray-core/releases/download/${version}/${asset}"

wget -qO "$tmp_dir/xray.zip" "$base_url" || { echo "Xray download failed." >&2; exit 1; }
wget -qO "$tmp_dir/xray.zip.dgst" "$base_url.dgst" || { echo "Xray digest download failed." >&2; exit 1; }
expected=$(awk -F'= *' 'toupper($1) == "SHA2-256" {print tolower($2); exit}' "$tmp_dir/xray.zip.dgst")
actual=$(sha256sum "$tmp_dir/xray.zip" | awk '{print tolower($1)}')
[ -n "$expected" ] && [ "$actual" = "$expected" ] || { echo "Xray SHA-256 verification failed." >&2; exit 1; }

unzip -q "$tmp_dir/xray.zip" -d "$tmp_dir/unpacked" || exit 1
[ -f "$tmp_dir/unpacked/xray" ] || { echo "Xray binary missing from archive." >&2; exit 1; }
chmod 755 "$tmp_dir/unpacked/xray"
if [ -s /etc/xray/config.json ]; then
  "$tmp_dir/unpacked/xray" run -test -config /etc/xray/config.json || {
    echo "The downloaded Xray version rejected the current configuration." >&2
    exit 1
  }
fi
install -m 755 "$tmp_dir/unpacked/xray" /usr/local/bin/xray.new
mv -f /usr/local/bin/xray.new /usr/local/bin/xray
EOF_XRAY_INSTALLER
chmod 700 /usr/local/sbin/xray-install-version

if ! /usr/local/sbin/xray-install-version "$XRAY_VER"; then
  echo "Unable to install a verified Xray Core ${XRAY_VER} binary."
  exit 1
fi

touch /etc/xray/vless.txt
chmod 600 /etc/xray/vless.txt

{
  printf 'XRAY_TLS_ALLOW_INSECURE=%q\n' "$XRAY_TLS_ALLOW_INSECURE"
  printf 'XRAY_CERT_SOURCE=%q\n' "$XRAY_CERT_SOURCE"
} > /etc/xray/server.env
chmod 600 /etc/xray/server.env

# XRAY CONFIGURATION
# Xray terminates TLS directly on 443 and dispatches transports by ALPN/path.
cat <<EOF > /etc/xray/config.json
{
  "log": { "access": "none", "error": "/var/log/xray/error.log", "loglevel": "error" },
  "inbounds": [
    {
      "tag": "vless-tls-dispatcher",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          { "alpn": "h2", "dest": 10444, "xver": 2 },
          { "path": "/xhttp", "dest": 10004, "xver": 2 },
          { "path": "/httpupgrade", "dest": 10005, "xver": 2 },
          { "path": "/vless-tcp", "dest": 10007, "xver": 2 },
          { "path": "/vless", "dest": 10003, "xver": 2 },
          { "dest": 666 }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "certificates": [
            { "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }
          ]
        },
        "sockopt": { "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-tcp-http",
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": { "header": { "type": "http", "request": { "path": ["/vless-tcp"] } } },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-plain-public",
      "port": "80,8080,8880",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          { "path": "/vless", "dest": 10003, "xver": 2 },
          { "path": "/httpupgrade", "dest": 10005, "xver": 2 },
          { "dest": 10080 }
        ]
      },
      "streamSettings": { "network": "tcp", "security": "none" }
    },
    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/vless" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-xhttp",
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": { "path": "/xhttp", "mode": "auto" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-httpupgrade",
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": { "path": "/httpupgrade", "host": "" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    },
    {
      "tag": "vless-grpc",
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": { "serviceName": "grpc-svc" },
        "sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ]
}
EOF
chmod 600 /etc/xray/config.json

mkdir -p /var/log/xray
if ! /usr/local/bin/xray run -test -config /etc/xray/config.json; then
  echo "Xray configuration validation failed. Review the Xray error printed above."
  exit 1
fi

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=2
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl disable --now haproxy 2>/dev/null || true
systemctl enable xray
systemctl restart xray

# === LEGACY HAPROXY CONFIGURATION (disabled; Xray owns port 443) ===
if false; then
# HAProxy terminates TLS once and dispatches VLESS by HTTP path or ALPN.
mkdir -p /etc/haproxy/certs
install -m 600 /etc/stunnel/stunnel.pem /etc/haproxy/certs/xray.pem
cat <<EOF_HAPROXY > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 100000
    daemon

defaults
    log global
    mode tcp
    option dontlognull
    timeout connect 5s
    timeout client 1h
    timeout client-fin 1h
    timeout server 1h
    timeout tunnel 1h
    timeout http-request 15s

frontend public_tls_443
    bind :443 v4v6 tfo ssl crt /etc/haproxy/certs/xray.pem alpn h2,http/1.1
    mode tcp
    acl negotiated_h2 ssl_fc_alpn -i h2
    acl h2_preface req.payload(0,24) -m bin 505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
    acl h1_vless_xhttp req.payload(0,500) -m reg /xhttp
    acl h1_vless_httpupgrade req.payload(0,500) -m reg /httpupgrade
    acl h1_vless_tcp req.payload(0,500) -m reg /vless-tcp
    acl h1_vless_ws req.payload(0,500) -m reg /vless
    acl clear_ssh req.payload(0,4) -m str SSH-

    # Do not accept generic HTTP as soon as its method is visible. Wait until
    # the complete VLESS path is buffered, otherwise /vless falls through to
    # the generic SSH WebSocket proxy.
    tcp-request inspect-delay 5s
    tcp-request content accept if h2_preface
    tcp-request content accept if h1_vless_xhttp
    tcp-request content accept if h1_vless_httpupgrade
    tcp-request content accept if h1_vless_tcp
    tcp-request content accept if h1_vless_ws
    tcp-request content accept if clear_ssh

    use_backend h2_dispatch if negotiated_h2 h2_preface

    # Specific paths must precede the shorter WebSocket path.
    use_backend vless_xhttp_h1 if h1_vless_xhttp
    use_backend vless_httpupgrade if h1_vless_httpupgrade
    use_backend vless_tcp_http if h1_vless_tcp
    use_backend vless_ws if h1_vless_ws

    use_backend sslh_clear if clear_ssh
    use_backend sslh_clear if HTTP

    default_backend sslh_clear

backend h2_dispatch
    server h2_router 127.0.0.1:10444 send-proxy-v2


frontend h2_router
    bind 127.0.0.1:10444 accept-proxy
    mode http

    # Match specific HTTP/2 transports first.
    use_backend vless_grpc_h2 if { path_beg /grpc-svc }
    use_backend vless_xhttp_h2 if { path_beg /xhttp }
    use_backend vless_httpupgrade if { path_beg /httpupgrade }
    use_backend vless_ws if { path_beg /vless }
    default_backend reject_h2

backend vless_tcp_http
    server xray 127.0.0.1:10007 send-proxy-v2

backend vless_ws
    mode http
    server xray 127.0.0.1:10003 send-proxy-v2

backend vless_httpupgrade
    mode http
    server xray 127.0.0.1:10005 send-proxy-v2

backend vless_xhttp_h1
    server xray 127.0.0.1:10004 send-proxy-v2

backend vless_xhttp_h2
    mode http
    server xray 127.0.0.1:10004 send-proxy-v2 proto h2

backend vless_grpc_h2
    mode http
    server xray 127.0.0.1:10006 send-proxy-v2 proto h2

backend sslh_clear
    server sslh 127.0.0.1:666

backend reject_h2
    mode http
    http-request return status 404
EOF_HAPROXY

if ! haproxy -c -f /etc/haproxy/haproxy.cfg; then
  echo "HAProxy configuration validation failed."
  exit 1
fi

mkdir -p /etc/systemd/system/haproxy.service.d
cat <<'EOF_HAPROXY_UNIT' > /etc/systemd/system/haproxy.service.d/xray-order.conf
[Unit]
After=xray.service network-online.target
Wants=xray.service network-online.target
EOF_HAPROXY_UNIT
systemctl daemon-reload
systemctl enable "$HAPROXY_SERVICE"
systemctl restart "$HAPROXY_SERVICE"
fi

# Internal-only HTTP/2 router. Xray owns public port 443 and sends negotiated
# h2 traffic here after TLS decryption; HAProxy separates gRPC from XHTTP.
cat <<'EOF_H2_ROUTER' > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 100000
    daemon

defaults
    log global
    mode http
    option dontlognull
    timeout connect 5s
    timeout client 1h
    timeout server 1h
    timeout tunnel 1h

frontend xray_h2_router
    bind 127.0.0.1:10444 accept-proxy proto h2
    mode http
    use_backend vless_grpc_h2 if { path_beg /grpc-svc/ }
    use_backend vless_xhttp_h2 if { path_beg /xhttp }
    default_backend reject_h2

backend vless_grpc_h2
    mode http
    server xray 127.0.0.1:10006 send-proxy-v2 proto h2

backend vless_xhttp_h2
    mode http
    server xray 127.0.0.1:10004 send-proxy-v2 proto h2

backend reject_h2
    mode http
    http-request return status 404
EOF_H2_ROUTER

if ! haproxy -c -f /etc/haproxy/haproxy.cfg; then
  echo "Internal HTTP/2 router validation failed."
  exit 1
fi
mkdir -p /etc/systemd/system/haproxy.service.d
cat <<'EOF_H2_UNIT' > /etc/systemd/system/haproxy.service.d/xray-order.conf
[Unit]
After=xray.service network-online.target
Wants=xray.service network-online.target
EOF_H2_UNIT
systemctl daemon-reload
systemctl enable haproxy
systemctl restart haproxy

# USER EXPIRY CRONJOB FOR XRAY
cat <<'EOF_EXP' > /usr/local/bin/exp-check
#!/bin/bash
set -o pipefail
umask 077
now=$(date +%Y-%m-%d)
CONFIG="/etc/xray/config.json"
[ -s "$CONFIG" ] || exit 0

exec 9>/run/lock/xray-config.lock
flock -w 30 9 || { logger -t xray-exp "Timed out waiting for the Xray config lock"; exit 1; }

work_dir=$(mktemp -d /tmp/xray-exp.XXXXXX) || exit 1
trap 'rm -rf "$work_dir"' EXIT

mapfile -t expired_users < <(
  for proto in vless; do
    db="/etc/xray/${proto}.txt"
    [ -f "$db" ] && awk -v d="$now" '$3 < d {print $1}' "$db"
  done | sort -u
)
[ "${#expired_users[@]}" -gt 0 ] || exit 0

expired_json=$(printf '%s\n' "${expired_users[@]}" | jq -R . | jq -s .) || exit 1
jq --argjson expired "$expired_json" '
  (.inbounds[] | select(((.settings.clients? // null) | type) == "array") | .settings.clients) |=
    map(. as $client | select(($expired | index($client.email)) == null)) |
  (.inbounds[] | select(((.settings.users? // null) | type) == "array") | .settings.users) |=
    map(. as $user | select(($expired | index($user.email)) == null))
' "$CONFIG" > "$work_dir/config.json" || exit 1

if ! /usr/local/bin/xray run -test -config "$work_dir/config.json" >/dev/null 2>&1; then
  logger -t xray-exp "Refusing expiry update: generated Xray config failed validation"
  exit 1
fi

cp -p "$CONFIG" "$work_dir/config.backup" || exit 1
install -m 600 "$work_dir/config.json" "$CONFIG" || exit 1
if ! systemctl restart xray; then
  install -m 600 "$work_dir/config.backup" "$CONFIG"
  systemctl restart xray || true
  logger -t xray-exp "Expiry update rolled back because Xray failed to restart"
  exit 1
fi

for proto in vless; do
  db="/etc/xray/${proto}.txt"
  [ -f "$db" ] || continue
  awk -v d="$now" '$3 >= d {print}' "$db" > "$work_dir/${proto}.txt" || exit 1
  install -m 600 "$work_dir/${proto}.txt" "$db" || exit 1
done
EOF_EXP
chmod +x /usr/local/bin/exp-check
echo "0 0 * * * root /usr/local/bin/exp-check >/dev/null 2>&1" > /etc/cron.d/xray-expiry

# USER EXPIRY CRONJOB FOR HYSTERIA
cat <<'EOF_HYST_EXP' > /usr/local/bin/hysteria-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
USER_DB="/etc/hysteria/users.txt"
CONFIG="/etc/hysteria/config.json"
changed=0

if [ -f "$USER_DB" ]; then
  mapfile -t expired_users < <(awk -v d="$now" '$2 < d {print $1}' "$USER_DB")
  for user in "${expired_users[@]}"; do
    jq ".inbounds[0].users |= map(select(.auth_str != \"$user\"))" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
    sed -i "/^$user /d" "$USER_DB"
    changed=1
  done
  if [ "$changed" -eq 1 ]; then
    systemctl restart hysteria-server
  fi
fi
EOF_HYST_EXP
chmod +x /usr/local/bin/hysteria-exp
echo "0 0 * * * root /usr/local/bin/hysteria-exp >/dev/null 2>&1" > /etc/cron.d/hysteria-expiry

# USER EXPIRY CRONJOB FOR HYSTERIA 2
cat <<'EOF_HYST2_EXP' > /usr/local/bin/hysteria2-exp
#!/bin/bash
set -o pipefail
umask 077
now=$(date +%Y-%m-%d)
user_db="/etc/hysteria2/users.txt"
[ -s "$user_db" ] || exit 0

exec 9>/run/lock/hysteria2-config.lock
flock -w 30 9 || exit 1
work_dir=$(mktemp -d /tmp/hysteria2-exp.XXXXXX) || exit 1
trap 'rm -rf "$work_dir"' EXIT

awk -v d="$now" '$3 >= d {print}' "$user_db" > "$work_dir/users.txt" || exit 1
cmp -s "$user_db" "$work_dir/users.txt" && exit 0
install -m 600 "$work_dir/users.txt" "$user_db"
EOF_HYST2_EXP
chmod 755 /usr/local/bin/hysteria2-exp
echo "5 0 * * * root /usr/local/bin/hysteria2-exp >/dev/null 2>&1" > /etc/cron.d/hysteria2-expiry

# USER EXPIRY CRONJOB FOR ZIVPN
cat <<'EOF_ZIVPN_EXP' > /usr/local/bin/zivpn-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
ZIVPN_USER_DB="/etc/zivpn/users.txt"
ZIVPN_CONFIG="/etc/zivpn/config.json"
changed=0
if [ -f "$ZIVPN_USER_DB" ]; then
  mapfile -t expired_users < <(awk -v d="$now" '$2 < d {print $1}' "$ZIVPN_USER_DB")
  for user in "${expired_users[@]}"; do
    jq ".auth.config |= map(select(. != \"$user\"))" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
    sed -i "/^$user /d" "$ZIVPN_USER_DB"
    changed=1
  done
  if [ "$changed" -eq 1 ]; then
    systemctl restart zivpn.service
  fi
fi
EOF_ZIVPN_EXP
chmod +x /usr/local/bin/zivpn-exp
echo "0 0 * * * root /usr/local/bin/zivpn-exp >/dev/null 2>&1" > /etc/cron.d/zivpn-expiry

# Nginx & Squid
rm -rf /home/vps/public_html /etc/nginx/sites-* /etc/nginx/nginx.conf; mkdir -p /home/vps/public_html
cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data; worker_processes auto; pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http { gzip on; gzip_vary on; gzip_comp_level 5; gzip_types text/plain application/x-javascript text/xml text/css; autoindex on; sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; server_tokens off; include /etc/nginx/mime.types; default_type application/octet-stream; access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log; client_max_body_size 32M; client_header_buffer_size 8m; large_client_header_buffers 8 8m; fastcgi_buffer_size 8m; fastcgi_buffers 8 8m; fastcgi_read_timeout 600; include /etc/nginx/conf.d/*.conf; }
myNginxC
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server { listen Nginx_Port; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { try_files $uri $uri/ /index.php?$args; } }
myvpsC
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf
systemctl restart "$NGINX_SERVICE"

rm -rf /etc/squid/squid.con*
cat <<'mySquid' > /etc/squid/squid.conf
acl server dst IP-ADDRESS/32 localhost
acl SSL_ports port 443 8443 1194
acl Safe_ports port 80 443 8443 1194 8080 8081 8880 2082 2086 3128 8000
acl CONNECT method CONNECT
http_port Squid_Port1
http_port Squid_Port2
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow server
http_access deny all
visible_hostname IP-ADDRESS
mySquid
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

# Health Checks
mkdir -p /etc/deekayvpn/health
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
#!/bin/bash
MYID="MYCHATID"; KEY="MYBOTID"; URL="https://api.telegram.org/bot${KEY}/sendMessage"
send_telegram_message() {
    [ -n "$MYID" ] && [ -n "$KEY" ] || return 0
    curl -s --max-time 10 --retry 5 --retry-delay 2 --retry-max-time 10 -d "chat_id=${MYID}&text=$1&disable_web_page_preview=true&parse_mode=markdown" "${URL}" >/dev/null 2>&1
}
server_ip="IPADDRESS"; datenow=$(date +"%Y-%m-%d %T"); IPCOUNTRY=$(curl -s "https://freeipapi.com/api/json/${server_ip}" | jq -r '.countryName')
STATE_DIR="/etc/deekayvpn/health"
check_port() { ss -lnt | awk '{print $4}' | grep -q ":$1$"; }
check_udp_port() { ss -lnu | awk '{print $4}' | grep -q ":$1$"; }
mark_fail() { local f="$STATE_DIR/$1.fail"; local n=0; [ -f "$f" ] && n=$(cat "$f"); n=$((n+1)); echo "$n" > "$f"; echo "$n"; }
clear_fail() { rm -f "$STATE_DIR/$1.fail"; }
restart_after_3_fails() {
    local fails=$(mark_fail "$1")
    if [ "$fails" -ge 3 ]; then
        systemctl restart "$2" >/dev/null 2>&1
        send_telegram_message "Service *$2* was offline or missing port(s) *$3* on server *${IPCOUNTRY}* ($server_ip). It has been auto-restarted at *${datenow}*."
        clear_fail "$1"
    fi
}
if check_port SSHPORT1 && check_port SSHPORT2 && systemctl is-active --quiet ssh; then clear_fail ssh; else restart_after_3_fails ssh ssh "SSHPORT1,SSHPORT2"; fi
if check_port DROPBEARPORT1 && check_port DROPBEARPORT2 && systemctl is-active --quiet dropbear; then clear_fail dropbear; else restart_after_3_fails dropbear dropbear "DROPBEARPORT1,DROPBEARPORT2"; fi
if check_port STUNNELPORT && systemctl is-active --quiet stunnel4; then clear_fail stunnel4; else restart_after_3_fails stunnel4 stunnel4 "STUNNELPORT"; fi
if check_port SSLHPORT && systemctl is-active --quiet sslh; then clear_fail sslh; else restart_after_3_fails sslh sslh "SSLHPORT"; fi
if check_port SQUIDPORT1 && check_port SQUIDPORT2 && systemctl is-active --quiet squid; then clear_fail squid; else restart_after_3_fails squid squid "SQUIDPORT1,SQUIDPORT2"; fi
if check_port NGINXPORT && systemctl is-active --quiet nginx; then clear_fail nginx; else restart_after_3_fails nginx nginx "NGINXPORT"; fi
for port in 10080 2082 2086; do if check_port $port && systemctl is-active --quiet ws-proxy@$port; then clear_fail ws-proxy-$port; else restart_after_3_fails ws-proxy-$port ws-proxy@$port "$port"; fi; done
if check_port 443 && check_port 10003 && check_port 10004 && check_port 10005 && check_port 10006 && check_port 10007 && systemctl is-active --quiet xray; then clear_fail xray; else restart_after_3_fails xray xray "443 and VLESS TLS transports"; fi
if check_port 10444 && systemctl is-active --quiet haproxy; then clear_fail haproxy; else restart_after_3_fails haproxy haproxy "internal h2 router 10444"; fi
if check_port OPENVPNTCPBACKEND && systemctl is-active --quiet openvpn-tcp; then clear_fail openvpn-tcp; else restart_after_3_fails openvpn-tcp openvpn-tcp "OPENVPNTCPBACKEND/TCP backend"; fi
if check_udp_port OPENVPNUDPPORT && systemctl is-active --quiet openvpn-udp; then clear_fail openvpn-udp; else restart_after_3_fails openvpn-udp openvpn-udp "OPENVPNUDPPORT/UDP"; fi
if check_port OPENVPNTCPPORT && check_port OPENVPNPAYLOADPORT && systemctl is-active --quiet openvpn-gateway; then clear_fail openvpn-gateway; else restart_after_3_fails openvpn-gateway openvpn-gateway "OPENVPNTCPPORT,OPENVPNPAYLOADPORT/TCP"; fi
if check_port OPENVPNSSLPORT && systemctl is-active --quiet stunnel4; then clear_fail openvpn-ssl; else restart_after_3_fails openvpn-ssl stunnel4 "OPENVPNSSLPORT/TCP"; fi
if systemctl is-active --quiet openvpn-nat; then clear_fail openvpn-nat; else restart_after_3_fails openvpn-nat openvpn-nat "forwarding/NAT"; fi
if systemctl is-active --quiet hysteria-server; then clear_fail hysteria-server; else restart_after_3_fails hysteria-server hysteria-server "UDP"; fi
if check_udp_port 36713 && systemctl is-active --quiet hysteria2-server; then clear_fail hysteria2-server; else restart_after_3_fails hysteria2-server hysteria2-server "36713/UDP"; fi
if systemctl is-active --quiet udp-custom; then clear_fail udp-custom; else restart_after_3_fails udp-custom udp-custom "UDP"; fi
if systemctl is-active --quiet zivpn; then clear_fail zivpn; else restart_after_3_fails zivpn zivpn "UDP"; fi
ServiceChecker

chmod 755 /etc/deekayvpn/service_checker.sh
sed -i "s|MYCHATID|$My_Chat_ID|g" /etc/deekayvpn/service_checker.sh
sed -i "s|MYBOTID|$My_Bot_Key|g" /etc/deekayvpn/service_checker.sh
sed -i "s|IPADDRESS|$IPADDR|g" /etc/deekayvpn/service_checker.sh
sed -i "s|DROPBEARPORT1|$Dropbear_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|DROPBEARPORT2|$Dropbear_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|STUNNELPORT|$Stunnel_Port_Num|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSLHPORT|$MainPort|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT1|$Squid_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT2|$Squid_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|NGINXPORT|$Nginx_Port|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT1|$SSH_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT2|$SSH_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|OPENVPNTCPPORT|$OPENVPN_TCP_PORT|g" /etc/deekayvpn/service_checker.sh
sed -i "s|OPENVPNUDPPORT|$OPENVPN_UDP_PORT|g" /etc/deekayvpn/service_checker.sh
sed -i "s|OPENVPNTCPBACKEND|$OPENVPN_TCP_BACKEND|g" /etc/deekayvpn/service_checker.sh
sed -i "s|OPENVPNPAYLOADPORT|$OPENVPN_PAYLOAD_PORT|g" /etc/deekayvpn/service_checker.sh
sed -i "s|OPENVPNSSLPORT|$OPENVPN_SSL_PORT|g" /etc/deekayvpn/service_checker.sh

echo "*/3 * * * * root /bin/bash /etc/deekayvpn/service_checker.sh >/dev/null 2>&1" > /etc/cron.d/service-checker
rm -f /etc/logrotate.d/rsyslog
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog /var/log/kern.log /var/log/auth.log /var/log/xray/error.log /var/log/nginx/*.log { 
    rotate 7; 
    daily; 
    maxsize 50M; 
    missingok; 
    notifempty; 
    compress; 
    delaycompress; 
    sharedscripts; 
    postrotate; 
        /bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true; 
        /bin/systemctl kill -s USR1 nginx.service >/dev/null 2>&1 || true;
    endscript; 
}
logrotate
chown root:root /var/log; chmod 755 /var/log; chown syslog:adm /var/log/syslog; chmod 640 /var/log/syslog
echo "*/5 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate
echo "0 3 * * * root sync; echo 3 > /proc/sys/vm/drop_caches" > /etc/cron.d/drop-cache

# ==========================================
# AGGRESSIVE SYSTEM & CONNTRACK TUNING
# ==========================================
# Force load nf_conntrack module
modprobe nf_conntrack 2>/dev/null || true; echo "nf_conntrack" > /etc/modules-load.d/freenet.conf
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
# File Descriptors
fs.file-max = 1048576

# Network Core
net.ipv4.ip_forward = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384

# TCP Settings
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

# SOCKS / WARP Local Loopback Optimization
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1

# Connection Tracking Limits (Prevents silent drops)
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60

# ZiVPN Required Socket Buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
SYSCTL
# Systemd Journal Log Cap
# Aggressive Systemd Journal Log Cap (RAM only to prevent socket freeze)
sed -i 's/.*SystemMaxUse.*/SystemMaxUse=10M/' /etc/systemd/journald.conf
sed -i 's/.*Storage.*/Storage=volatile/' /etc/systemd/journald.conf
grep -q "^SystemMaxUse=10M" /etc/systemd/journald.conf || echo "SystemMaxUse=10M" >> /etc/systemd/journald.conf
grep -q "^Storage=volatile" /etc/systemd/journald.conf || echo "Storage=volatile" >> /etc/systemd/journald.conf
systemctl restart systemd-journald
sysctl --system || true
# Prevent Rsyslog from writing heavy VPN logs to disk
cat <<'EOF' > /etc/rsyslog.d/99-vpn-discard.conf
:programname, isequal, "dropbear" stop
:programname, isequal, "sslh" stop
:programname, isequal, "sshd" stop
:programname, isequal, "stunnel" stop
EOF
systemctl restart rsyslog
mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

# SLOWDNS
rm -rf /etc/slowdns; mkdir -m 777 /etc/slowdns
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS
After=network.target
[Service]
ExecStart=/etc/slowdns/sldns-server -udp :53 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:$SSH_Port2
Restart=on-failure
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload; systemctl enable server-sldns; systemctl restart server-sldns

# === HYSTERIA v1 (Sing-box v1.13.13) & CLOUDFLARE WARP ===
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install -y cloudflare-warp

warp-cli --accept-tos disconnect 2>/dev/null || true
warp-cli --accept-tos registration delete 2>/dev/null || true
warp-cli --accept-tos registration new 2>/dev/null || warp-cli --accept-tos register
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40000
warp-cli --accept-tos connect
sleep 2

# Silence noisy warp-svc telemetry
echo "Applying log limits to warp-svc..."
mkdir -p /etc/systemd/system/warp-svc.service.d
cat <<EOF > /etc/systemd/system/warp-svc.service.d/logging.conf
[Service]
LogLevelMax=warning
EOF
systemctl daemon-reload
systemctl restart warp-svc

# Upgraded to the stable v1.13.13 core
wget -qO /tmp/sing-box.deb "https://github.com/SagerNet/sing-box/releases/download/v1.13.13/sing-box_1.13.13_linux_amd64.deb"
dpkg -i /tmp/sing-box.deb
apt-mark hold sing-box
rm -f /tmp/sing-box.deb

mkdir -p /etc/hysteria
HYST_PORT="${UDP_PORT##*:}"

cat << EOF > /etc/hysteria/hysteria.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 40:26:da:91:18:2b:77:9c:85:6a:0c:bb:ca:90:53:fe
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=KobZ
        Validity
            Not Before: Jul 22 22:23:55 2020 GMT
            Not After : Jul 20 22:23:55 2030 GMT
        Subject: CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (1024 bit)
                Modulus:
                    00:ce:35:23:d8:5d:9f:b6:9b:cb:6a:89:e1:90:af:
                    42:df:5f:f8:bd:ad:a7:78:9a:ca:20:f0:3d:5b:d6:
                    c9:ef:4c:4a:99:96:c3:38:fd:59:b4:d7:65:ed:d4:
                    a7:fa:ab:03:e2:be:88:2f:ca:fc:90:dd:b0:b7:bc:
                    23:cb:83:ac:36:e2:01:57:69:64:b8:e1:9e:51:f0:
                    a6:9d:13:d9:92:6b:4d:04:a6:10:64:a3:3f:6b:ff:
                    fe:32:ac:91:63:c2:71:24:be:9e:76:4f:87:cc:3a:
                    03:a1:9e:48:3f:11:92:33:3b:19:16:9c:d0:5d:16:
                    ee:c1:42:67:99:47:66:67:67
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: CA:FALSE
            X509v3 Subject Key Identifier: 6B:08:C0:64:10:71:A8:32:7F:0B:FE:1E:98:1F:BD:72:74:0F:C8:66
            X509v3 Authority Key Identifier: keyid:64:49:32:6F:FE:66:62:F1:57:4D:BB:91:A8:5D:BD:26:3E:51:A4:D2
                DirName:/CN=KobZ
                serial:01:A4:01:02:93:12:D9:D6:01:A9:83:DC:03:73:DA:ED:C8:E3:C3:B7
            X509v3 Extended Key Usage: TLS Web Server Authentication
            X509v3 Key Usage: Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: DNS:server
    Signature Algorithm: sha256WithRSAEncryption
         a1:3e:ac:83:0b:e5:5d:ca:36:b7:d0:ab:d0:d9:73:66:d1:62:
         88:ce:3d:47:9e:08:0b:a0:5b:51:13:fc:7e:d7:6e:17:0e:bd:
         f5:d9:a9:d9:06:78:52:88:5a:e5:df:d3:32:22:4a:4b:08:6f:
         b1:22:80:4f:19:d1:5f:9d:b6:5a:17:f7:ad:70:a9:04:00:ff:
         fe:84:aa:e1:cb:0e:74:c0:1a:75:0b:3e:98:90:1d:22:ba:a4:
         7a:26:65:7d:d1:3b:5c:45:a1:77:22:ed:b6:6b:18:a3:c4:ee:
         3e:06:bb:0b:ec:12:ac:16:a5:50:b3:ed:46:43:87:72:fd:75:8c:38
-----BEGIN CERTIFICATE-----
MIICVDCCAb2gAwIBAgIQQCbakRgrd5yFagy7ypBT/jANBgkqhkiG9w0BAQsFADAP
MQ0wCwYDVQQDDARLb2JaMB4XDTIwMDcyMjIyMjM1NVoXDTMwMDcyMDIyMjM1NVow
ETEPMA0GA1UEAwwGc2VydmVyMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDO
NSPYXZ+2m8tqieGQr0LfX/i9rad4msog8D1b1snvTEqZlsM4/Vm012Xt1Kf6qwPi
vogvyvyQ3bC3vCPLg6w24gFXaWS44Z5R8KadE9mSa00EphBkoz9r//4yrJFjwnEk
vp52T4fMOgOhnkg/EZIzOxkWnNBdFu7BQmeZR2ZnZwIDAQABo4GuMIGrMAkGA1Ud
EwQCMAAwHQYDVR0OBBYEFGsIwGQQcagyfwv+HpgfvXJ0D8hmMEoGA1UdIwRDMEGA
FGRJMm/+ZmLxV027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAEC
kxLZ1gGpg9wDc9rtyOPDtzATBgNVHSUEDDAKBggrBgEFBQcDATALBgNVHQ8EBAMC
BaAwEQYDVR0RBAowCIIGc2VydmVyMA0GCSqGSIb3DQEBCwUAA4GBAKE+rIML5V3K
NrfQq9DZc2bRYojOPUeeCAugW1ET/H7XbhcOvfXZqdkGeFKIWuXf0zIiSksIb7Ei
gE8Z0V+dtloX961wqQQA//6EquHLDnTAGnULPpiQHSK6pHomZX3RO1xFoXci7bZr
GKPE7j4GuwvsEqwWpVCz7UZDh3L9dYw4
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/hysteria/hysteria.key
-----BEGIN PRIVATE KEY-----
MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAM41I9hdn7aby2qJ
4ZCvQt9f+L2tp3iayiDwPVvWye9MSpmWwzj9WbTXZe3Up/qrA+K+iC/K/JDdsLe8
I8uDrDbiAVdpZLjhnlHwpp0T2ZJrTQSmEGSjP2v//jKskWPCcSS+nnZPh8w6A6Ge
SD8RkjM7GRac0F0W7sFCZ5lHZmdnAgMBAAECgYAFNrC+UresDUpaWjwaxWOidDG8
0fwu/3Lm3Ewg21BlvX8RXQ94jGdNPDj2h27r1pEVlY2p767tFr3WF2qsRZsACJpI
qO1BaSbmhek6H++Fw3M4Y/YY+JD+t1eEBjJMa+DR5i8Vx3AE8XOdTXmkl/xK4jaB
EmLYA7POyK+xaDCeEQJBAPJadiYd3k9OeOaOMIX+StCs9OIMniRz+090AJZK4CMd
jiOJv0mbRy945D/TkcqoFhhScrke9qhgZbgFj11VbDkCQQDZ0aKBPiZdvDMjx8WE
y7jaltEDINTCxzmjEBZSeqNr14/2PG0X4GkBL6AAOLjEYgXiIvwfpoYE6IIWl3re
ebCfAkAHxPimrixzVGux0HsjwIw7dl//YzIqrwEugeSG7O2Ukpz87KySOoUks3Z1
yV2SJqNWskX1Q1Xa/gQkyyDWeCeZAkAbyDBI+ctc8082hhl8WZunTcs08fARM+X3
FWszc+76J1F2X7iubfIWs6Ndw95VNgd4E2xDATNg1uMYzJNgYvcTAkBoE8o3rKkp
em2n0WtGh6uXI9IC29tTQGr3jtxLckN/l9KsJ4gabbeKNoes74zdena1tRdfGqUG
JQbf7qSE3mg2
-----END PRIVATE KEY-----
EOF

cat > /etc/hysteria/config.json <<EOF
{
  "log": { "level": "fatal" },
  "inbounds": [
    {
      "type": "hysteria",
      "tag": "hy1-inbound",
      "listen": "0.0.0.0",
      "listen_port": $HYST_PORT,
      "up_mbps": 1000,
      "down_mbps": 1000,
      "obfs": "$OBFS",
      "users": [ { "auth_str": "$PASSWORD" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/hysteria/hysteria.crt", "key_path": "/etc/hysteria/hysteria.key" }
    }
  ],
  "outbounds": [
    { "type": "socks", "tag": "warp-proxy", "server": "127.0.0.1", "server_port": 40000 },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      {
        "inbound": "hy1-inbound",
        "network": "udp",
       "domain_suffix": [ 
          "doubleclick.net", 
          "googlesyndication.com", "googleadservices.com", "admob.com", 
          "google-analytics.com", "app-measurement.com", "adservice.google.com", 
          "g.doubleclick.net", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", 
          "gvt1.com", "gvt2.com", "gvt3.com", "googleanalytics.com", 
          "analytics.google.com", "googleadapis.com", "adsense.com" 
        ],
        "outbound": "block"
      },
      {
       "inbound": "hy1-inbound",
        "domain_suffix": [ 
          "doubleclick.net", 
          "googlesyndication.com", "googleadservices.com", "admob.com", 
          "googleapis.com", "google-analytics.com", "app-measurement.com", 
          "adservice.google.com", "g.doubleclick.net", "google.com", 
          "pagead2.googlesyndication.com", "tpc.googlesyndication.com", 
          "gvt1.com", "gvt2.com", "gvt3.com", "gstatic.com", 
          "googleusercontent.com", "ggpht.com", "play.google.com", 
          "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", 
          "fundingchoicesmessages.google.com", "imasdk.googleapis.com", 
          "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", 
          "mtalk.google.com", "googleadapis.com", 
          "accounts.google.com", "play.googleapis.com", "android.apis.google.com", 
          "adsense.com", "1e100.net" 
        ],
        "outbound": "warp-proxy"
      },
      { "inbound": "hy1-inbound", "outbound": "direct" }
    ],
    "auto_detect_interface": true
  }
}
EOF

chmod 755 /etc/hysteria/config.json /etc/hysteria/hysteria.crt /etc/hysteria/hysteria.key
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/hysteria/users.txt

cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Sing-Box Hysteria v1 Core
After=network.target
[Service]
User=root
ExecStart=/usr/bin/sing-box run -c /etc/hysteria/config.json
Restart=on-failure
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-server.service; systemctl start hysteria-server.service

# === HYSTERIA 2 (official core, separate from Hysteria 1) ===
HYSTERIA2_VER="app/v2.9.3"
case "$(uname -m)" in
  x86_64|amd64) HYSTERIA2_ASSET="hysteria-linux-amd64" ;;
  i386|i486|i586|i686) HYSTERIA2_ASSET="hysteria-linux-386" ;;
  aarch64|arm64) HYSTERIA2_ASSET="hysteria-linux-arm64" ;;
  armv7l|armv7*) HYSTERIA2_ASSET="hysteria-linux-arm" ;;
  *) echo "Unsupported Hysteria 2 architecture: $(uname -m)"; exit 1 ;;
esac

HYSTERIA2_RELEASE_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA2_VER/\//%2F}"
hyst2_tmp=$(mktemp -d /tmp/hysteria2-install.XXXXXX) || exit 1
if ! curl -fL --retry 3 -o "$hyst2_tmp/$HYSTERIA2_ASSET" "$HYSTERIA2_RELEASE_URL/$HYSTERIA2_ASSET" ||
   ! curl -fL --retry 3 -o "$hyst2_tmp/hashes.txt" "$HYSTERIA2_RELEASE_URL/hashes.txt"; then
  rm -rf "$hyst2_tmp"
  echo "Hysteria 2 download failed."
  exit 1
fi
hyst2_expected=$(awk -v asset="$HYSTERIA2_ASSET" '$2 == asset || $2 == "build/" asset || $2 == "*" asset {print tolower($1); exit}' "$hyst2_tmp/hashes.txt")
hyst2_actual=$(sha256sum "$hyst2_tmp/$HYSTERIA2_ASSET" | awk '{print tolower($1)}')
if [ -z "$hyst2_expected" ] || [ "$hyst2_actual" != "$hyst2_expected" ]; then
  rm -rf "$hyst2_tmp"
  echo "Hysteria 2 SHA-256 verification failed."
  exit 1
fi
install -m 755 "$hyst2_tmp/$HYSTERIA2_ASSET" /usr/local/bin/hysteria2
rm -rf "$hyst2_tmp"

mkdir -p /etc/hysteria2
mkdir -p /usr/local/libexec
cat <<'EOF_HYST2_AUTH' > /usr/local/libexec/hysteria2-auth
#!/bin/bash
user_db="/etc/hysteria2/users.txt"
auth="$2"
[ -n "$auth" ] && [ -r "$user_db" ] || exit 1
awk -v token="$auth" '$2 == token {print $1; found=1; exit} END {exit !found}' "$user_db"
EOF_HYST2_AUTH
chmod 700 /usr/local/libexec/hysteria2-auth

HYST2_INITIAL_TOKEN=$(cat /proc/sys/kernel/random/uuid)
jq -n \
  --arg listen ":$HYST2_PORT" \
  --arg cert "/etc/xray/xray.crt" \
  --arg key "/etc/xray/xray.key" \
  --arg obfs "$OBFS" '
  {
    listen: $listen,
    tls: {cert: $cert, key: $key},
    auth: {type: "command", command: "/usr/local/libexec/hysteria2-auth"},
    obfs: {type: "salamander", salamander: {password: $obfs}},
    masquerade: {
      type: "proxy",
      proxy: {url: "https://www.microsoft.com/", rewriteHost: true}
    }
  }
' > /etc/hysteria2/config.json
chmod 600 /etc/hysteria2/config.json
printf 'default %s %s\n' "$HYST2_INITIAL_TOKEN" "$(date -d '+365 days' +%Y-%m-%d)" > /etc/hysteria2/users.txt
chmod 600 /etc/hysteria2/users.txt

cat <<'EOF_HYST2_SERVICE' > /etc/systemd/system/hysteria2-server.service
[Unit]
Description=Official Hysteria 2 Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria2 server --config /etc/hysteria2/config.json
Restart=on-failure
RestartSec=2s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadOnlyPaths=/etc/xray/xray.crt /etc/xray/xray.key
ReadWritePaths=/etc/hysteria2

[Install]
WantedBy=multi-user.target
EOF_HYST2_SERVICE

iptables -C INPUT -p udp --dport "$HYST2_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST2_PORT" -j ACCEPT
netfilter-persistent save >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable hysteria2-server.service
if ! systemctl restart hysteria2-server.service; then
  journalctl -u hysteria2-server -n 50 --no-pager
  echo "Hysteria 2 failed to start."
  exit 1
fi

# NAT & Iptables Configuration
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
cat > /etc/systemd/system/hysteria-nat.service <<EOF
[Unit]
Description=Restore Hysteria UDP NAT rules
After=network-online.target
Wants=network-online.target
Before=hysteria-server.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport $HYST_PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $HYST_PORT -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-nat.service; systemctl start hysteria-nat.service

# Creating startup script
cat <<'deekayz' > /etc/deekaystartup
#!/bin/sh
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "nameserver DNS1" > /etc/resolv.conf; echo "nameserver DNS2" >> /etc/resolv.conf
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid

# Standard INPUT rule for Port 53
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT

# 🚨 NEW FIX: VIP Pass for Port 53 (Prevents UDP Custom from swallowing SlowDNS traffic)
iptables -t nat -C PREROUTING -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j ACCEPT

# Keep Hysteria 2 out of the broad Hysteria 1 and UDP-Custom DNAT ranges.
# These exemptions must remain ahead of all range/catch-all DNAT rules.
iptables -t nat -C PREROUTING -p udp --dport 36713 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 36713 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 443 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 443 -j ACCEPT

# Hysteria NAT Routing
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712
deekayz

sed -i "s|MyTimeZone|$MyVPS_Time|g" /etc/deekaystartup
sed -i "s|DNS1|$Dns_1|g" /etc/deekaystartup
sed -i "s|DNS2|$Dns_2|g" /etc/deekaystartup

cat <<'deekayx' > /etc/systemd/system/deekaystartup.service
[Unit]
Description=Custom startup script
ConditionPathExists=/etc/deekaystartup
[Service]
Type=oneshot
ExecStart=/etc/deekaystartup
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
deekayx
chmod +x /etc/deekaystartup; systemctl enable deekaystartup

# BadVPN Binary (Provides 127.0.0.1:7300 upstream for UDP Custom)
if [ "$(getconf LONG_BIT)" == "64" ]; then
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
chmod +x /usr/bin/badvpn-udpgw

cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn tun2socks service
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --loglevel none --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn; systemctl start badvpn

# === UDP CUSTOM (Port 36717) ===
echo "Installing UDP Custom..."
mkdir -p /root/udp
wget -q -O /root/udp/udp-custom "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/bin/udp-custom-linux-amd64" || true
chmod +x /root/udp/udp-custom 2>/dev/null || true
wget -q -O /root/udp/config.json "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/config/config.json" || true
sed -i "s/\":36712\"/\":36717\"/g" /root/udp/config.json 2>/dev/null || true
chmod 644 /root/udp/config.json 2>/dev/null || true

cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Proxy
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom server -c /root/udp/config.json
Restart=always
RestartSec=2s
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable udp-custom; systemctl start udp-custom 2>/dev/null || true

# === ZIVPN (Port 5667) ===
echo "Installing ZiVPN..."
mkdir -p /etc/zivpn
wget -q -O /usr/local/bin/zivpn "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64" || true
chmod +x /usr/local/bin/zivpn 2>/dev/null || true
cp /etc/hysteria/hysteria.crt /etc/zivpn/zivpn.crt 2>/dev/null || true
cp /etc/hysteria/hysteria.key /etc/zivpn/zivpn.key 2>/dev/null || true
chmod 644 /etc/zivpn/zivpn.crt /etc/zivpn/zivpn.key 2>/dev/null || true

cat > /etc/zivpn/config.json <<EOF
{
  "listen": ":5667",
   "cert": "/etc/zivpn/zivpn.crt",
   "key": "/etc/zivpn/zivpn.key",
   "obfs":"$OBFS",
   "auth": {
    "mode": "passwords", 
    "config": ["$PASSWORD"]
  }
}
EOF
chmod 644 /etc/zivpn/config.json
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/zivpn/users.txt

cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=zivpn VPN Server
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/zivpn-nat.service <<EOF
[Unit]
Description=Restore ZiVPN UDP NAT rules
After=network-online.target
Wants=network-online.target
Before=zivpn.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5667 -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable zivpn.service; systemctl start zivpn.service 2>/dev/null || true
systemctl enable zivpn-nat.service; systemctl start zivpn-nat.service 2>/dev/null || true

# VNSTAT INITIALIZATION
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
vnstat -u -i "$IFACE" 2>/dev/null || true
systemctl enable vnstat
systemctl restart vnstat

# MENU CREATION - FULL AND UNCOMPRESSED
mkdir -p /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash

# Modern Color Palette
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)

HYST_CONFIG="/etc/hysteria/config.json"
HYST_USER_DB="/etc/hysteria/users.txt"
HYST2_CONFIG="/etc/hysteria2/config.json"
HYST2_USER_DB="/etc/hysteria2/users.txt"
HYST2_PORT="36713"
ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USER_DB="/etc/zivpn/users.txt"
XRAY_CONFIG="/etc/xray/config.json"
XRAY_SERVER_ENV="/etc/xray/server.env"
OPENVPN_USER_DB="/etc/openvpn/users.db"
OPENVPN_PROFILE="/etc/openvpn/client-template.ovpn"
OPENVPN_TCP_PORT="1194"
OPENVPN_UDP_PORT="1194"
OPENVPN_TCP_BACKEND="11940"
OPENVPN_SSL_PORT="8443"
OPENVPN_PAYLOAD_PORT="8081"
OPENVPN_PROXY_PORT="3128"
[ -f "$XRAY_SERVER_ENV" ] && source "$XRAY_SERVER_ENV"
touch "$HYST_USER_DB" "$ZIVPN_USER_DB" /etc/xray/vless.txt 2>/dev/null || true

# --- Utility Functions ---
server_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
cpu_count() { nproc 2>/dev/null || echo "1"; }
mem_stats() { free -h 2>/dev/null | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }
valid_server_name() {
  local value="$1" IFS=. octet
  local -a parts
  if [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    read -r -a parts <<< "$value"
    [ "${#parts[@]}" -eq 4 ] || return 1
    for octet in "${parts[@]}"; do
      [[ "$octet" =~ ^[0-9]{1,3}$ ]] && (( 10#$octet <= 255 )) || return 1
    done
    return 0
  fi
  [ "${#value}" -le 253 ] &&
    [[ "$value" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]
}

server_status() {
  local ok=0
  for s in ssh dropbear stunnel4 squid nginx server-sldns hysteria-server hysteria2-server ws-proxy@10080 xray badvpn udp-custom zivpn openvpn-tcp openvpn-udp openvpn-gateway openvpn-nat; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 6 ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}ISSUES DETECTED${NC}"
}
pause_return() { echo; read -rp "Press ENTER to return... " _; }

# --- ZIVPN MANAGEMENT FUNCTIONS ---
add_zivpn() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CREATE ZIVPN USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Enter Password: " new_pass
    
    if grep -qw "^$new_pass" "$ZIVPN_USER_DB" 2>/dev/null; then
        echo -e "\n${RED}Error: User/Password already exists!${NC}"
        pause_return; return
    fi
    read -rp " Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    jq ".auth.config += [\"$new_pass\"]" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
    echo "$new_pass $exp_date" >> "$ZIVPN_USER_DB"
    systemctl restart zivpn.service
    
    OBFS_VAL=$(jq -r '.obfs' "$ZIVPN_CONFIG" 2>/dev/null || echo "GuruzScript")
    
    echo -e "\n${GREEN}✔ User created successfully!${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
    echo -e " ${BOLD}Domain:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
    echo -e " ${BOLD}Port Range:${NC}  ${YELLOW}6000-19999${NC}"
    echo -e " ${BOLD}User (Pass):${NC} ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}Obfs:${NC}        ${YELLOW}${OBFS_VAL}${NC}"
    echo -e " ${BOLD}Expiry Date:${NC} ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    pause_return
}

del_zivpn() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}DELETE ZIVPN USER${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "No users found."; pause_return; return; fi
    cat -n "$ZIVPN_USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to delete: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi

    del_pass=$(sed -n "${del_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
    if [ -z "$del_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi

    jq ".auth.config |= map(select(. != \"$del_pass\"))" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
    sed -i "${del_id}d" "$ZIVPN_USER_DB"
    systemctl restart zivpn.service
    echo -e "\n${GREEN}✔ User '$del_pass' deleted successfully!${NC}"
    pause_return
}

extend_zivpn() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EXTEND ZIVPN USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "No users found."; pause_return; return; fi

    cat -n "$ZIVPN_USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to extend: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi
    
    ext_pass=$(sed -n "${ext_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$ZIVPN_USER_DB" | awk '{print $2}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi
    
    read -rp " Add Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    
    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$ZIVPN_USER_DB"
    
    echo -e "\n${GREEN}✔ User '$ext_pass' extended successfully!${NC}\n New Expiry: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_zivpn() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}ZIVPN USERS LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "\n No active users found.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "PASSWORD" "EXPIRY DATE"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$ZIVPN_USER_DB" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " Total Active Users: ${YELLOW}$(wc -l < "$ZIVPN_USER_DB")${NC}"
    fi
    pause_return
}

# --- HYSTERIA MANAGEMENT FUNCTIONS ---
add_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CREATE HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Enter Password/Auth String: " new_pass
    
    if grep -qw "^$new_pass" "$HYST_USER_DB" 2>/dev/null || jq -e ".inbounds[0].users[] | select(.auth_str == \"$new_pass\")" "$HYST_CONFIG" >/dev/null; then
        echo -e "\n${RED}Error: User/Password already exists!${NC}"
        pause_return; return
    fi
    read -rp " Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}]" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
    echo "$new_pass $exp_date" >> "$HYST_USER_DB"
    systemctl restart hysteria-server
    
    OBFS_VAL=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG" 2>/dev/null || echo "GuruzScript")
    
    echo -e "\n${GREEN}✔ User created successfully!${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
    echo -e " ${BOLD}Domain:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
    echo -e " ${BOLD}Port Range:${NC}  ${YELLOW}20000-50000${NC}"
    echo -e " ${BOLD}User (Pass):${NC} ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}Obfs:${NC}        ${YELLOW}${OBFS_VAL}${NC}"
    echo -e " ${BOLD}Expiry Date:${NC} ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    pause_return
}

del_hysteria() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}DELETE HYSTERIA USER${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "No users found."; pause_return; return; fi
    cat -n "$HYST_USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to delete: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi

    del_pass=$(sed -n "${del_id}p" "$HYST_USER_DB" | awk '{print $1}')
    if [ -z "$del_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi

    jq ".inbounds[0].users |= map(select(.auth_str != \"$del_pass\"))" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
    sed -i "${del_id}d" "$HYST_USER_DB"
    systemctl restart hysteria-server
    echo -e "\n${GREEN}✔ User '$del_pass' deleted successfully!${NC}"
    pause_return
}

extend_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EXTEND HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "No users found."; pause_return; return; fi

    cat -n "$HYST_USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to extend: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi
    
    ext_pass=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $2}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi
    
    read -rp " Add Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    
    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$HYST_USER_DB"
    
    echo -e "\n${GREEN}✔ User '$ext_pass' extended successfully!${NC}\n New Expiry: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}HYSTERIA USERS LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "\n No active users found.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "PASSWORD (AUTH STRING)" "EXPIRY DATE"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$HYST_USER_DB" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " Total Active Users: ${YELLOW}$(wc -l < "$HYST_USER_DB")${NC}"
    fi
    pause_return
}

speed_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EDIT UP/DOWN SPEEDS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_up=$(jq -r '.inbounds[0].up_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
    current_down=$(jq -r '.inbounds[0].down_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
    echo -e " Current Upload:   ${YELLOW}${current_up} Mbps${NC}"
    echo -e " Current Download: ${YELLOW}${current_down} Mbps${NC}\n"
    read -rp " Enter New Upload Speed (Mbps): " new_up
    read -rp " Enter New Download Speed (Mbps): " new_down
    if [[ "$new_up" =~ ^[0-9]+$ ]] && [[ "$new_down" =~ ^[0-9]+$ ]]; then
        jq ".inbounds[0].up_mbps = $new_up | .inbounds[0].down_mbps = $new_down" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
        systemctl restart hysteria-server
        echo -e "\n${GREEN}✔ Speeds updated successfully!${NC}"
    else echo -e "\n${RED}Invalid input. Numbers only.${NC}"; fi
    pause_return
}

# --- HYSTERIA 2 MANAGEMENT FUNCTIONS ---
print_hysteria2_link() {
  local user="$1" token="$2" encoded_token encoded_obfs insecure
  encoded_token=$(jq -nr --arg v "$token" '$v|@uri')
  encoded_obfs=$(jq -nr --arg v "$(jq -r '.obfs.salamander.password' "$HYST2_CONFIG")" '$v|@uri')
  [ -f "$XRAY_SERVER_ENV" ] && source "$XRAY_SERVER_ENV"
  insecure="1"
  echo "hysteria2://${encoded_token}@${DOMAIN}:${HYST2_PORT}?insecure=${insecure}&sni=${DOMAIN}&obfs=salamander&obfs-password=${encoded_obfs}#${user}-HY2"
}

add_hysteria2() {
  clear
  echo -e "${CYAN}CREATE HYSTERIA 2 ACCOUNT${NC}"
  read -rp " Username: " user
  [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] || { echo -e "${RED}Invalid username.${NC}"; pause_return; return; }
  if awk -v u="$user" '$1 == u {found=1} END {exit !found}' "$HYST2_USER_DB" 2>/dev/null; then
    echo -e "${RED}Username already exists.${NC}"; pause_return; return
  fi
  read -rp " Validity (Days): " days
  [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "${RED}Invalid validity.${NC}"; pause_return; return; }
  token=$(cat /proc/sys/kernel/random/uuid)
  exp=$(date -d "+${days} days" +%Y-%m-%d)
  printf '%s %s %s\n' "$user" "$token" "$exp" >> "$HYST2_USER_DB"
  chmod 600 "$HYST2_USER_DB"
  echo -e "${GREEN}Hysteria 2 account created.${NC}\nUsername: $user\nToken: $token\nExpiry: $exp\n"
  print_hysteria2_link "$user" "$token"
  pause_return
}

del_hysteria2() {
  clear
  [ -s "$HYST2_USER_DB" ] || { echo "No Hysteria 2 users found."; pause_return; return; }
  nl -w2 -s'. ' "$HYST2_USER_DB"
  read -rp " User ID to delete: " id
  [[ "$id" =~ ^[0-9]+$ ]] || { echo -e "${RED}Invalid ID.${NC}"; pause_return; return; }
  user=$(sed -n "${id}p" "$HYST2_USER_DB" | awk '{print $1}')
  [ -n "$user" ] || { echo -e "${RED}ID not found.${NC}"; pause_return; return; }
  sed -i "${id}d" "$HYST2_USER_DB"
  echo -e "${GREEN}Hysteria 2 user '$user' deleted.${NC}"
  pause_return
}

extend_hysteria2() {
  clear
  [ -s "$HYST2_USER_DB" ] || { echo "No Hysteria 2 users found."; pause_return; return; }
  nl -w2 -s'. ' "$HYST2_USER_DB"
  read -rp " User ID to renew: " id
  [[ "$id" =~ ^[0-9]+$ ]] || { echo -e "${RED}Invalid ID.${NC}"; pause_return; return; }
  line=$(sed -n "${id}p" "$HYST2_USER_DB")
  user=$(awk '{print $1}' <<< "$line"); token=$(awk '{print $2}' <<< "$line"); old_exp=$(awk '{print $3}' <<< "$line")
  [ -n "$user" ] || { echo -e "${RED}ID not found.${NC}"; pause_return; return; }
  read -rp " Add Validity (Days): " days
  [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "${RED}Invalid validity.${NC}"; pause_return; return; }
  base="$old_exp"; [ "$old_exp" < "$(date +%Y-%m-%d)" ] && base="$(date +%Y-%m-%d)"
  new_exp=$(date -d "$base +${days} days" +%Y-%m-%d)
  sed -i "${id}s/.*/$user $token $new_exp/" "$HYST2_USER_DB"
  echo -e "${GREEN}Hysteria 2 user renewed until $new_exp.${NC}"
  pause_return
}

list_hysteria2() {
  clear
  echo -e "${CYAN}HYSTERIA 2 USERS${NC}"
  if [ -s "$HYST2_USER_DB" ]; then nl -w2 -s'. ' "$HYST2_USER_DB"; else echo "No users found."; fi
  pause_return
}

show_hysteria2() {
  clear
  [ -s "$HYST2_USER_DB" ] || { echo "No Hysteria 2 users found."; pause_return; return; }
  nl -w2 -s'. ' "$HYST2_USER_DB"
  read -rp " User ID: " id
  line=$(sed -n "${id}p" "$HYST2_USER_DB")
  user=$(awk '{print $1}' <<< "$line"); token=$(awk '{print $2}' <<< "$line")
  [ -n "$user" ] || { echo -e "${RED}ID not found.${NC}"; pause_return; return; }
  echo
  print_hysteria2_link "$user" "$token"
  pause_return
}

# --- XRAY MANAGEMENT FUNCTIONS ---
xray_commit_tmp() {
  local tmp="$1" test_log="${1}.test.log" backup="${1}.backup"
  if ! (
    flock -w 30 9 || { echo -e "${RED}Timed out waiting for the Xray configuration lock.${NC}"; exit 1; }
    if ! jq empty "$tmp" >/dev/null 2>&1; then
      echo -e "${RED}Generated JSON is invalid.${NC}"
      exit 1
    fi
    if ! /usr/local/bin/xray run -test -config "$tmp" >"$test_log" 2>&1; then
      echo -e "${RED}Xray rejected the generated configuration:${NC}"
      cat "$test_log"
      exit 1
    fi
    cp -p "$XRAY_CONFIG" "$backup" || exit 1
    install -m 600 "$tmp" "$XRAY_CONFIG" || exit 1
    if ! systemctl restart xray; then
      install -m 600 "$backup" "$XRAY_CONFIG"
      systemctl restart xray || true
      echo -e "${RED}Xray failed to restart; the previous configuration was restored.${NC}"
      exit 1
    fi
  ) 9>/run/lock/xray-config.lock; then
    rm -f "$tmp" "$test_log" "$backup"
    return 1
  fi
  rm -f "$tmp" "$test_log" "$backup"
}

print_vless_links() {
  local user="$1" uuid="$2"
  [ -f "$XRAY_SERVER_ENV" ] && source "$XRAY_SERVER_ENV"
  local tls_insecure="1"
  echo -e "\n${YELLOW}[ VLESS TLS / SHARED PORT 443 ]${NC}\n"
  echo -e "TCP HTTP:  vless://${uuid}@${DOMAIN}:443?type=tcp&headerType=http&security=tls&encryption=none&host=${DOMAIN}&path=%2Fvless-tcp&sni=${DOMAIN}&insecure=1&allowInsecure=${tls_insecure}#${user}-VLESS-TCP\n"
  echo -e "WS:        vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&insecure=1&allowInsecure=${tls_insecure}#${user}-VLESS-WS\n"
  echo -e "XHTTP:     vless://${uuid}@${DOMAIN}:443?type=xhttp&security=tls&encryption=none&path=%2Fxhttp&host=${DOMAIN}&sni=${DOMAIN}&insecure=1&allowInsecure=${tls_insecure}&mode=auto&alpn=h2%2Chttp%2F1.1#${user}-VLESS-XHTTP\n"
  echo -e "HTTPUp:    vless://${uuid}@${DOMAIN}:443?type=httpupgrade&security=tls&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}&sni=${DOMAIN}&insecure=1&allowInsecure=${tls_insecure}#${user}-VLESS-HTTPUp\n"
  echo -e "gRPC:      vless://${uuid}@${DOMAIN}:443?type=grpc&security=tls&encryption=none&serviceName=grpc-svc&sni=${DOMAIN}&insecure=1&allowInsecure=${tls_insecure}&alpn=h2#${user}-VLESS-gRPC\n"

  echo -e "${YELLOW}[ VLESS NTLS (80/8080/8880) ]${NC}\n"
  echo -e "TCP: vless://${uuid}@${DOMAIN}:80?type=tcp&security=none&encryption=none#${user}-VLESS-NTLS-TCP\n"
  echo -e "WS:  vless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}-VLESS-NTLS-WS\n"
  echo -e "HUP: vless://${uuid}@${DOMAIN}:80?type=httpupgrade&security=none&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}#${user}-VLESS-NTLS-HTTPUp\n"
}

add_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREATE XRAY ACCOUNT${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e " VLESS (TCP, WS, XHTTP, HTTPUpgrade and gRPC)"

  read -rp " Username: " user
  if ! [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo -e "${RED}Username may contain only letters, numbers, dot, underscore and hyphen.${NC}"; pause_return; return
  fi
  if awk -v u="$user" '$1==u {found=1} END {exit !found}' /etc/xray/vless.txt 2>/dev/null; then
    echo -e "${RED}Username already exists.${NC}"; pause_return; return
  fi

  read -rp " Validity (Days): " masa
  [[ "$masa" =~ ^[0-9]+$ ]] && [ "$masa" -gt 0 ] || { echo -e "${RED}Invalid validity.${NC}"; pause_return; return; }
  exp=$(date -d "+${masa} days" +"%Y-%m-%d")

  uuid=$(cat /proc/sys/kernel/random/uuid)
  read -rp " Use a custom UUID? (y/N): " custom_uuid_prompt
  if [[ "$custom_uuid_prompt" =~ ^[Yy]$ ]]; then
    read -rp " Enter custom UUID: " uuid
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]] || { echo -e "${RED}Invalid UUID.${NC}"; pause_return; return; }
  fi

  tmp=$(mktemp /tmp/xray-menu.XXXXXX.json)
  jq --arg uuid "$uuid" --arg user "$user" '
    .inbounds |= map(
      if .protocol == "vless" and .tag != "vless-tls-dispatcher" and (((.settings.clients? // null) | type) == "array") then
        .settings.clients += [{"id":$uuid,"email":$user}]
      else . end
    )
  ' "$XRAY_CONFIG" > "$tmp" || { rm -f "$tmp"; pause_return; return; }

  if ! xray_commit_tmp "$tmp"; then pause_return; return; fi

  echo "$user $uuid $exp" >> /etc/xray/vless.txt

  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                 ${BOLD}XRAY ACCOUNT CREATED${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "Username: $user\nExpiry:   $exp"
  print_vless_links "$user" "$uuid"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

del_xray() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}DELETE XRAY ACCOUNT${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  mapfile -t users < <(awk '{print $1}' /etc/xray/vless.txt 2>/dev/null | sort -u)
  if [ ${#users[@]} -eq 0 ]; then echo -e "${YELLOW}No Xray users found.${NC}"; pause_return; return; fi
  for i in "${!users[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${users[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] Cancel\n"
  read -rp " Select user to delete: " idx
  [[ "$idx" == "00" || "$idx" == "0" ]] && return
  [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -gt 0 ] && [ "$idx" -le "${#users[@]}" ] || { echo -e "${RED}Invalid selection.${NC}"; pause_return; return; }
  user="${users[$((idx-1))]}"
  tmp=$(mktemp /tmp/xray-menu.XXXXXX.json)
  jq --arg user "$user" '
    (.inbounds[] | select(((.settings.clients? // null) | type) == "array") | .settings.clients) |= map(select(.email != $user)) |
    (.inbounds[] | select(((.settings.users? // null) | type) == "array") | .settings.users) |= map(select(.email != $user))
  ' "$XRAY_CONFIG" > "$tmp" || { rm -f "$tmp"; pause_return; return; }
  xray_commit_tmp "$tmp" || { pause_return; return; }
  for db in /etc/xray/vless.txt; do
    [ -f "$db" ] || continue
    db_tmp=$(mktemp "${db}.XXXXXX") || continue
    if awk -v u="$user" '$1 != u {print}' "$db" > "$db_tmp"; then
      install -m 600 "$db_tmp" "$db"
    fi
    rm -f "$db_tmp"
  done
  echo -e "\n${GREEN}✔ User $user deleted successfully.${NC}"
  pause_return
}

renew_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RENEW XRAY ACCOUNT${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Username to renew: " user
  if ! awk -v u="$user" '$1==u {found=1} END {exit !found}' /etc/xray/vless.txt 2>/dev/null; then
    echo -e "${RED}User not found.${NC}"; pause_return; return
  fi
  read -rp " Add Validity (Days): " days
  [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "${RED}Invalid validity.${NC}"; pause_return; return; }
  new_exp=""
  for proto in vless; do
    db="/etc/xray/${proto}.txt"
    if awk -v u="$user" '$1==u {found=1} END {exit !found}' "$db" 2>/dev/null; then
      current_exp=$(awk -v u="$user" '$1==u {print $3; exit}' "$db")
      credential=$(awk -v u="$user" '$1==u {print $2; exit}' "$db")
      new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
      awk -v u="$user" -v c="$credential" -v e="$new_exp" '$1==u {$0=u" "c" "e} {print}' "$db" > "${db}.tmp" && mv "${db}.tmp" "$db"
    fi
  done
  echo -e "\n${GREEN}✔ User '$user' renewed successfully.${NC}\nNew Expiry: $new_exp"
  pause_return
}

show_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}SHOW XRAY CONFIG LINKS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Username to view: " user
  if awk -v u="$user" '$1==u {found=1} END {exit !found}' /etc/xray/vless.txt 2>/dev/null; then
    uuid=$(awk -v u="$user" '$1==u {print $2; exit}' /etc/xray/vless.txt)
    print_vless_links "$user" "$uuid"
  else
    echo -e "${RED}User not found.${NC}"
  fi
  pause_return
}

# --- OPENVPN STANDALONE ACCOUNT MANAGEMENT ---
openvpn_payload_template() {
  printf '%s' 'GET /openvpn HTTP/1.1[crlf]Host: [host][crlf]Connection: keep-alive[crlf][crlf]'
}

select_openvpn_user() {
  local purpose="$1" idx
  mapfile -t OVPN_USERS < <(/usr/local/libexec/openvpn-userctl list 2>/dev/null)
  if [ "${#OVPN_USERS[@]}" -eq 0 ]; then
    echo -e "${RED}No OpenVPN accounts found.${NC}"
    return 1
  fi
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  printf " %-56s \n" "${BOLD}$purpose${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  for i in "${!OVPN_USERS[@]}"; do
    printf "  [${YELLOW}%02d${NC}] %-22s Exp: %s\n" $((i+1)) "$(awk '{print $1}' <<< "${OVPN_USERS[$i]}")" "$(awk '{print $2}' <<< "${OVPN_USERS[$i]}")"
  done
  echo -e "\n  [${YELLOW}00${NC}] Back\n"
  read -rp "  Select account: " idx
  [[ "$idx" == "0" || "$idx" == "00" ]] && return 1
  [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#OVPN_USERS[@]}" ] || return 1
  OPENVPN_SELECTED_USER=$(awk '{print $1}' <<< "${OVPN_USERS[$((idx-1))]}")
  OPENVPN_SELECTED_EXP=$(awk '{print $2}' <<< "${OVPN_USERS[$((idx-1))]}")
  return 0
}

print_openvpn_generator_details() {
  local user="$1" exp="$2" pass payload
  pass=$(/usr/local/libexec/openvpn-userctl secret "$user" 2>/dev/null || true)
  payload=$(openvpn_payload_template)
  clear
  echo -e "${GREEN}════════════════ OPENVPN GENERATOR DETAILS ════════════════${NC}"
  echo -e " ${BOLD}Host:${NC}             ${YELLOW}$DOMAIN${NC}"
  echo -e " ${BOLD}OVPN TCP:${NC}         ${YELLOW}$OPENVPN_TCP_PORT${NC}"
  echo -e " ${BOLD}OVPN UDP:${NC}         ${YELLOW}$OPENVPN_UDP_PORT${NC}"
  echo -e " ${BOLD}OVPN SSL:${NC}         ${YELLOW}$OPENVPN_SSL_PORT${NC}"
  echo -e " ${BOLD}Payload Gateway:${NC}  ${YELLOW}$OPENVPN_PAYLOAD_PORT${NC}"
  echo -e " ${BOLD}HTTP Proxy:${NC}       ${YELLOW}$OPENVPN_PROXY_PORT${NC} (also 8000)"
  echo -e " ${BOLD}OVPN Username:${NC}    ${YELLOW}$user${NC}"
  echo -e " ${BOLD}OVPN Password:${NC}    ${YELLOW}${pass:-Unavailable - reset password}${NC}"
  echo -e " ${BOLD}Expiry:${NC}           ${YELLOW}$exp${NC}"
  echo -e " ${BOLD}Profile:${NC}          ${YELLOW}$OPENVPN_PROFILE${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e " ${BOLD}SERVER tab in TGVPN Generator:${NC}"
  echo -e "   OpenVPN 3 profile : paste the COMPLETE output from 'Show Generic .ovpn Profile'"
  echo -e "   OVPN TCP          : $OPENVPN_TCP_PORT"
  echo -e "   OVPN UDP          : $OPENVPN_UDP_PORT"
  echo -e "   OVPN SSL          : $OPENVPN_SSL_PORT"
  echo -e "   OVPN Username     : $user"
  echo -e "   OVPN Password     : ${pass:-<reset password first>}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e " ${BOLD}TWEAK presets supported by TunnelGuard/OpenVPN3:${NC}"
  echo -e "   TCP Direct              : no extra fields"
  echo -e "   UDP Direct              : no extra fields"
  echo -e "   Direct Payload          : Payload = ${YELLOW}$payload${NC}"
  echo -e "   HTTP PROXY > PAYLOAD    : ProxyHost=[host] ProxyPort=$OPENVPN_PAYLOAD_PORT"
  echo -e "                             Payload = ${YELLOW}$payload${NC}"
  echo -e "   Direct SSL              : SNI=[host]"
  echo -e "   SSL > PAYLOAD           : SNI=[host], Payload = ${YELLOW}$payload${NC}"
  echo -e "   SSL PROXY > PAYLOAD     : SNI=[host] ProxyHost=[host] ProxyPort=$OPENVPN_SSL_PORT"
  echo -e "                             Payload = ${YELLOW}$payload${NC}"
  echo -e "   HTTP PROXY              : ProxyHost=[host] ProxyPort=$OPENVPN_PROXY_PORT, no payload"
  echo -e "   SSL Proxy               : SNI=[host] ProxyHost=[host] ProxyPort=$OPENVPN_SSL_PORT, no payload"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
}

add_openvpn() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "               ${BOLD}CREATE OPENVPN ACCOUNT${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Username: " user
  [[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] && [ "$user" != "." ] && [ "$user" != ".." ] || { echo -e "${RED}Invalid username.${NC}"; pause_return; return; }
  if /usr/local/libexec/openvpn-userctl list | awk -v u="$user" '$1==u {found=1} END {exit !found}'; then
    echo -e "${RED}OpenVPN username already exists.${NC}"; pause_return; return
  fi
  read -rsp " Password (press ENTER to auto-generate): " pass; echo
  [ -n "$pass" ] || pass=$(openssl rand -hex 12)
  read -rp " Validity (Days): " days
  [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "${RED}Invalid validity.${NC}"; pause_return; return; }
  exp=$(date -d "+${days} days" +%Y-%m-%d)
  if ! /usr/local/libexec/openvpn-userctl add "$user" "$pass" "$exp"; then
    echo -e "${RED}Unable to create OpenVPN account.${NC}"; pause_return; return
  fi
  print_openvpn_generator_details "$user" "$exp"
  echo
  echo -e "${GREEN}✔ Standalone OpenVPN account created.${NC}"
  echo -e "${YELLOW}The generic .ovpn profile is shared by all OpenVPN users on this VPS.${NC}"
  pause_return
}

renew_openvpn() {
  select_openvpn_user "RENEW OPENVPN ACCOUNT" || { pause_return; return; }
  read -rp " Add Validity (Days): " days
  [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "${RED}Invalid validity.${NC}"; pause_return; return; }
  base="$OPENVPN_SELECTED_EXP"
  [ "$base" '<' "$(date +%Y-%m-%d)" ] && base="$(date +%Y-%m-%d)"
  new_exp=$(date -d "$base +${days} days" +%Y-%m-%d)
  /usr/local/libexec/openvpn-userctl renew "$OPENVPN_SELECTED_USER" "$new_exp" && \
    echo -e "${GREEN}OpenVPN account renewed until $new_exp.${NC}"
  pause_return
}

reset_openvpn_password() {
  select_openvpn_user "RESET OPENVPN PASSWORD" || { pause_return; return; }
  read -rsp " New password (press ENTER to auto-generate): " pass; echo
  [ -n "$pass" ] || pass=$(openssl rand -hex 12)
  if /usr/local/libexec/openvpn-userctl passwd "$OPENVPN_SELECTED_USER" "$pass"; then
    echo -e "${GREEN}Password updated.${NC}"
    echo -e "New OpenVPN password: ${YELLOW}$pass${NC}"
    echo -e "Update OVPN Password for this server in the generator."
  else
    echo -e "${RED}Password reset failed.${NC}"
  fi
  pause_return
}

delete_openvpn() {
  select_openvpn_user "DELETE OPENVPN ACCOUNT" || { pause_return; return; }
  read -rp " Delete '$OPENVPN_SELECTED_USER'? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    /usr/local/libexec/openvpn-userctl delete "$OPENVPN_SELECTED_USER" && echo -e "${GREEN}OpenVPN account deleted.${NC}"
  fi
  pause_return
}

list_openvpn() {
  clear
  echo -e "${CYAN}OPENVPN ACCOUNTS${NC}"
  if [ ! -s "$OPENVPN_USER_DB" ]; then
    echo "No OpenVPN users found."
  elif ! /usr/local/libexec/openvpn-userctl list | nl -w2 -s'. '; then
    echo "Unable to read OpenVPN users."
  fi
  pause_return
}

show_openvpn_generator() {
  select_openvpn_user "OPENVPN GENERATOR DETAILS" || { pause_return; return; }
  print_openvpn_generator_details "$OPENVPN_SELECTED_USER" "$OPENVPN_SELECTED_EXP"
  pause_return
}

show_openvpn_profile() {
  clear
  echo -e "${CYAN}════════ GENERIC OPENVPN PROFILE FOR GENERATOR ════════${NC}"
  echo -e "${YELLOW}Copy EVERYTHING between BEGIN and END into the generator's OpenVPN 3 profile field.${NC}\n"
  echo "-----BEGIN OPENVPN PROFILE-----"
  cat "$OPENVPN_PROFILE" 2>/dev/null || echo "Profile not found."
  echo "-----END OPENVPN PROFILE-----"
  pause_return
}

# --- SSH USER FUNCTIONS ---
list_real_users() { awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null; }

select_user() {
  local purpose="$1"
  mapfile -t USERS < <(list_real_users)
  if [ "${#USERS[@]}" -eq 0 ]; then echo -e "${RED}No active user accounts found.${NC}"; return 1; fi
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  printf " %-56s \n" "${BOLD}$purpose${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  for i in "${!USERS[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${USERS[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] Back\n"
  read -rp "  Select an account number: " idx
  [[ "$idx" == "00" || "$idx" == "0" ]] && return 1
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#USERS[@]}"; then echo -e "${RED}  Invalid selection.${NC}"; return 1; fi
  SELECTED_USER="${USERS[$((idx-1))]}"
  return 0
}

create_user() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREATE NEW SSH USER${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  Username: " user
  read -rp "  Password: " pass
  read -rp "  Valid for (days): " days

  if [ -z "$user" ] || [ -z "$pass" ] || [ -z "$days" ]; then echo -e "\n${RED}  Error: All fields are required.${NC}"; pause_return; return; fi
  if id "$user" >/dev/null 2>&1; then echo -e "\n${RED}  Error: User '$user' already exists.${NC}"; pause_return; return; fi

  useradd -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" && echo "$user:$pass" | chpasswd

  IP=$(curl -s ipv4.icanhazip.com)
  CURRENT_NS=$(grep 'ExecStart=' /etc/systemd/system/server-sldns.service 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')

  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}ACCOUNT CREATED SUCCESSFULLY${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}Domain/Host${NC}: ${YELLOW}$DOMAIN${NC}"
  echo -e "  ${BOLD}IP Address${NC} : ${YELLOW}$IP${NC}"
  echo -e "  ${BOLD}Username${NC}   : ${YELLOW}$user${NC}"
  echo -e "  ${BOLD}Password${NC}   : ${YELLOW}$pass${NC}"
  echo -e "  ${BOLD}Expiry${NC}     : ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  SSH Port   : 22, 299"
  echo -e "  Dropbear   : 80"
  echo -e "  SSL/TLS    : 443"
  echo -e "  SSL/WS     : 443"
  echo -e "  WebSocket  : 80, 8080, 8880, 2082, 2086"
  echo -e "  SlowDNS    : 53"
  echo -e "  UDP Custom : 1-65535"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}Payload HTTP     :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e ""
  echo -e "  ${BOLD}Payload Enhanced :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: bug.com[crlf][crlf]PATCH / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}SlowDNS NS ${NC}: ${YELLOW}${CURRENT_NS:-Not Set}${NC}"
  echo -e "  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

delete_user() {
  if ! select_user "DELETE SSH USER"; then pause_return; return; fi
  clear; echo -e "${RED}Warning: You are about to delete user: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Are you sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    pkill -u "$SELECTED_USER" 2>/dev/null
    if userdel -r -f "$SELECTED_USER" 2>/dev/null || userdel -f "$SELECTED_USER" 2>/dev/null; then
        echo -e "${GREEN}User $SELECTED_USER has been deleted.${NC}"
    else
        echo -e "${RED}Failed to delete $SELECTED_USER. Check for locked files.${NC}"
    fi
  fi
  pause_return
}

extend_user() {
  if ! select_user "EXTEND USER EXPIRY"; then pause_return; return; fi
  clear; echo -e "Extending account for: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Enter number of days to add: " days
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number format.${NC}"; pause_return; return; fi
  current=$(chage -l "$SELECTED_USER" 2>/dev/null | awk -F": " '/Account expires/ {print $2}')
  if [ "$current" = "never" ] || [ -z "$current" ]; then new_exp=$(date -d "+$days days" +%Y-%m-%d)
  else new_exp=$(date -d "$current +$days days" +%Y-%m-%d); fi
  chage -E "$new_exp" "$SELECTED_USER"
  echo -e "${GREEN}Success!${NC} Account extended.\nNew Expiry Date: ${YELLOW}$new_exp${NC}"
  pause_return
}

# --- Monitor ---
online_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "         ${YELLOW}REAL-TIME ACTIVE USERS (PROCESS MONITOR)${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e " ${GREEN}Username           | Protocol   | Active Sessions${NC} "
    echo -e "${CYAN}--------------------------------------------------------------${NC}"

    declare -A ssh_sessions
    declare -A dropbear_sessions

    # Get all valid VPN users (UID >= 1000)
    valid_users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

    active_found=0

    for user in $valid_users; do
        # Count processes running under the authenticated user
        ssh_count=$(ps -u "$user" 2>/dev/null | grep -c "sshd")
        drop_count=$(ps -u "$user" 2>/dev/null | grep -c "dropbear")

        if [ "$ssh_count" -gt 0 ]; then
            ssh_sessions["$user"]=$ssh_count
            active_found=1
        fi
        
        if [ "$drop_count" -gt 0 ]; then
            dropbear_sessions["$user"]=$drop_count
            active_found=1
        fi
    done

    if [ "$active_found" -eq 0 ]; then
        echo -e " No active SSH or Dropbear users found right now."
    else
        # Output Dropbear Users
        for user in "${!dropbear_sessions[@]}"; do
            count="${dropbear_sessions[$user]}"
            if [ "$count" -gt 1 ]; then
                printf " %-18s | Dropbear   | ${RED}%-8s (Multi-Login)${NC}\n" "$user" "$count"
            else
                printf " %-18s | Dropbear   | ${GREEN}%-8s${NC}\n" "$user" "$count"
            fi
        done

        # Output OpenSSH Users
        for user in "${!ssh_sessions[@]}"; do
            count="${ssh_sessions[$user]}"
            if [ "$count" -gt 1 ]; then
                printf " %-18s | OpenSSH    | ${RED}%-8s (Multi-Login)${NC}\n" "$user" "$count"
            else
                printf " %-18s | OpenSSH    | ${GREEN}%-8s${NC}\n" "$user" "$count"
            fi
        done
    fi

    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${GREEN}OpenVPN Active Sessions${NC}"
    ovpn_found=0
    for status_file in /run/openvpn/tcp-status.log /run/openvpn/udp-status.log; do
      [ -r "$status_file" ] || continue
      proto=$(basename "$status_file" | cut -d- -f1 | tr '[:lower:]' '[:upper:]')
      while IFS=',' read -r tag common _rest; do
        [ "$tag" = "CLIENT_LIST" ] || continue
        [ -n "$common" ] || continue
        printf " %-18s | OpenVPN-%-3s | ${GREEN}active${NC}\n" "$common" "$proto"
        ovpn_found=1
      done < "$status_file"
    done
    [ "$ovpn_found" -eq 1 ] || echo " No active OpenVPN users found right now."

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -n 1 -s -r -p "Press any key to return to menu..."
}

# --- Service Controls ---
restart_service() {
  local service_name="$1"
  local display_name="$2"
  echo -e "Restarting ${display_name}..."
  systemctl restart $service_name 2>/dev/null || true
  echo -e "${GREEN}✔ ${display_name} restarted.${NC}"
}

service_control_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}SERVICE CONTROLS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] Restart All Services"
    echo -e "  [${YELLOW}02${NC}] Restart SSH & Dropbear"
    echo -e "  [${YELLOW}03${NC}] Restart Node WebSocket Proxies"
    echo -e "  [${YELLOW}04${NC}] Restart Stunnel & Xray Core"
    echo -e "  [${YELLOW}05${NC}] Restart Squid Proxy & Nginx"
    echo -e "  [${YELLOW}06${NC}] Restart UDP Core (SlowDNS/Hysteria/ZiVPN/UDP-Custom)"
    echo -e "  [${YELLOW}07${NC}] Restart OpenVPN Stack"
    echo -e "  [${YELLOW}00${NC}] Back\n"
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) restart_service "ssh dropbear stunnel4 sslh squid nginx server-sldns hysteria-server hysteria2-server badvpn udp-custom zivpn ws-proxy@10080 ws-proxy@2082 ws-proxy@2086 xray openvpn-nat openvpn-tcp openvpn-udp openvpn-gateway" "All Services"; pause_return ;;
      2|02) restart_service "ssh dropbear" "SSH & Dropbear"; pause_return ;;
      3|03) restart_service "ws-proxy@10080 ws-proxy@2082 ws-proxy@2086" "Node WebSocket Proxies"; pause_return ;;
      4|04) restart_service "stunnel4 xray" "Stunnel & Xray Core"; pause_return ;;
      5|05) restart_service "squid nginx" "Squid Proxy & Nginx"; pause_return ;;
      6|06) restart_service "server-sldns hysteria-server hysteria2-server badvpn udp-custom zivpn" "UDP Core Services"; pause_return ;;
      7|07) restart_service "openvpn-nat openvpn-tcp openvpn-udp openvpn-gateway stunnel4" "OpenVPN Stack"; pause_return ;;
      0|00) break ;;
      *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

# --- Backup & Restore ---
backup_snapshot() {
  clear; local out="/root/guruzgh_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  echo -e "Packaging server configurations..."
  tar -czf "$out" /etc/ssh /etc/default/dropbear /etc/stunnel /etc/squid /etc/hysteria /etc/hysteria2 /etc/zivpn /etc/openvpn /root/udp /etc/deekayvpn /etc/systemd/system/ws-proxy@.service /etc/systemd/system/hysteria2-server.service /usr/local/libexec/hysteria2-auth /usr/local/libexec/openvpn-auth /usr/local/libexec/openvpn-userctl /usr/local/libexec/openvpn-nat /etc/systemd/system/openvpn-tcp.service /etc/systemd/system/openvpn-udp.service /etc/systemd/system/openvpn-gateway.service /etc/systemd/system/openvpn-nat.service /etc/xray /etc/haproxy/haproxy.cfg /etc/systemd/system/haproxy.service.d 2>/dev/null
  echo -e "\n${GREEN}✔ Backup successfully created!${NC}\nLocation: ${YELLOW}$out${NC}"
  pause_return
}

restore_snapshot() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RESTORE CONFIGURATION${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  shopt -s nullglob
  backups=(/root/guruzgh_backup_*.tar.gz)
  if [ ${#backups[@]} -eq 0 ]; then echo -e "${RED}  No backup files found in /root/.${NC}"; pause_return; return; fi
  echo -e "  Available Backups:\n"
  for i in "${!backups[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(basename "${backups[$i]}")"; done
  echo -e "\n  [${YELLOW}00${NC}] Cancel\n"
  read -rp "  Select backup to restore: " sel
  if [[ "$sel" == "00" || "$sel" == "0" ]]; then return; fi
  idx=$((sel-1))
  if [ -n "${backups[$idx]}" ]; then
    echo -e "\nRestoring ${YELLOW}$(basename "${backups[$idx]}")${NC}..."
    tar -xzf "${backups[$idx]}" -C /
    systemctl daemon-reload; systemctl restart ssh dropbear stunnel4 sslh squid nginx server-sldns hysteria-server hysteria2-server badvpn udp-custom zivpn ws-proxy@10080 ws-proxy@2082 ws-proxy@2086 xray haproxy openvpn-nat openvpn-tcp openvpn-udp openvpn-gateway 2>/dev/null || true
    echo -e "${GREEN}✔ Restore complete!${NC}"
  else echo -e "${RED}Invalid selection.${NC}"; fi
  pause_return
}

# --- System Utilities ---
utilities_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}SYSTEM UTILITIES${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}1${NC}] Enable Native Kernel BBR (Fast & Silent)"
    echo -e "  [${YELLOW}2${NC}] Check Netflix & Streaming Unlocks (English)"
    echo -e "  [${YELLOW}0${NC}] Back\n"
    read -rp "  Select an option: " subopt
    case "$subopt" in 
      1) 
         echo -e "\nEnabling Native Kernel BBR..."
         sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
         sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
         echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
         echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
         sysctl -p >/dev/null 2>&1
         if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null)" == *"bbr"* ]]; then echo -e "${GREEN}✔ BBR Successfully Enabled!${NC}"
         else echo -e "${RED}✖ Failed to enable BBR (Kernel might not support it).${NC}"; fi
         pause_return
         ;; 
      2) 
         clear
         echo -e "${YELLOW}Running Region Restriction Check (English)...${NC}\n"
         bash <(curl -sL https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en
         echo ""
         pause_return 
         ;;
      0) break ;;
      *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

# --- Domain & DNS Management ---
change_domain() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CHANGE SERVER DOMAIN${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_dom=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || echo "Not Set")
    echo -e " Current Domain/IP: ${YELLOW}$current_dom${NC}\n"
    read -rp " Enter New Domain or IP: " new_dom
    if [ -n "$new_dom" ]; then
        if ! valid_server_name "$new_dom"; then
            echo -e "\n${RED}Enter a valid DNS hostname or IPv4 address.${NC}"
            pause_return
            return
        fi
        echo "$new_dom" > /etc/deekayvpn/domain.txt; DOMAIN="$new_dom"
        tls_insecure=1
        if [ "${XRAY_CERT_SOURCE:-self-signed}" = "letsencrypt" ]; then
            if [[ "$new_dom" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                openssl x509 -in /etc/xray/xray.crt -noout -checkip "$new_dom" >/dev/null 2>&1 && tls_insecure=0
            else
                openssl x509 -in /etc/xray/xray.crt -noout -checkhost "$new_dom" >/dev/null 2>&1 && tls_insecure=0
            fi
        fi
        if grep -q '^XRAY_TLS_ALLOW_INSECURE=' "$XRAY_SERVER_ENV" 2>/dev/null; then
            sed -i "s/^XRAY_TLS_ALLOW_INSECURE=.*/XRAY_TLS_ALLOW_INSECURE=$tls_insecure/" "$XRAY_SERVER_ENV"
        else
            echo "XRAY_TLS_ALLOW_INSECURE=$tls_insecure" >> "$XRAY_SERVER_ENV"
        fi
        XRAY_TLS_ALLOW_INSECURE="$tls_insecure"
        echo -e "\n${GREEN}✔ Domain successfully updated to: $new_dom${NC}"
        [ "$tls_insecure" -eq 1 ] && echo -e "${YELLOW}The installed certificate does not verify this name; generated links will use allowInsecure=1 until a matching certificate is installed.${NC}"
    else echo -e "\n${RED}Action cancelled.${NC}"; fi
    pause_return
}

change_slowdns() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}CHANGE SLOWDNS NAMESERVER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    svc_file="/etc/systemd/system/server-sldns.service"
    if [ ! -f "$svc_file" ]; then echo -e "${RED}SlowDNS service file not found.${NC}"; pause_return; return; fi
    current_ns=$(grep 'ExecStart=' "$svc_file" | sed 's/.*server\.key \([^ ]*\) .*/\1/')
    echo -e " Current Nameserver: ${YELLOW}$current_ns${NC}\n"
    read -rp " Enter New Nameserver (e.g., ns1.domain.com): " new_ns
    if [ -n "$new_ns" ] && [ "$new_ns" != "$current_ns" ]; then
        sed -i "s/$current_ns/$new_ns/g" "$svc_file"
        systemctl daemon-reload; systemctl restart server-sldns
        echo -e "\n${GREEN}✔ SlowDNS Nameserver updated to: $new_ns${NC}"
    else echo -e "\n${RED}Action cancelled or identical NS entered.${NC}"; fi
    pause_return
}

# --- Advanced / Danger Zone ---
advanced_menu() {
  while true; do
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}ADVANCED SETTINGS${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] View Raw Hysteria JSON"
    echo -e "  [${YELLOW}02${NC}] View Service Action Logs (Journalctl)"
    echo -e "  [${YELLOW}03${NC}] Change Server Domain/IP"
    echo -e "  [${YELLOW}04${NC}] Change SlowDNS Nameserver (NS)"
    echo -e "  [${RED}05${NC}] Full Script Uninstall (Danger)"
    echo -e "  [${YELLOW}00${NC}] Back\n"
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) clear; cat /etc/hysteria/config.json 2>/dev/null || echo "Not found."; pause_return ;;
    2|02) 
        clear; echo -e "[1] SSH  [2] WS-Proxies  [3] Hysteria 1  [4] Stunnel  [5] SlowDNS  [6] Xray  [7] UDP Custom  [8] ZiVPN  [9] Xray H2 Router  [10] Hysteria 2  [11] OpenVPN\n"
        read -rp "Select log: " lopt
        case "$lopt" in
          1) journalctl -u ssh -n 50 --no-pager ;;
          2) journalctl -u ws-proxy@10080 -n 50 --no-pager ;;
          3) journalctl -u hysteria-server -n 50 --no-pager ;;
          4) journalctl -u stunnel4 -n 50 --no-pager ;;
          5) journalctl -u server-sldns -n 50 --no-pager ;;
          6) journalctl -u xray -n 50 --no-pager ;;
          7) journalctl -u udp-custom -n 50 --no-pager ;;
          8) journalctl -u zivpn -n 50 --no-pager ;;
          9) journalctl -u haproxy -n 50 --no-pager ;;
          10) journalctl -u hysteria2-server -n 50 --no-pager ;;
          11) journalctl -u openvpn-tcp -u openvpn-udp -u openvpn-gateway -u openvpn-nat -n 100 --no-pager ;;
        esac; pause_return ;;
      3|03) change_domain ;;
      4|04) change_slowdns ;;
      5|05) remove_script ;;
      0|00) break ;;
    esac
  done
}

remove_script() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                     ${BOLD}FULL UNINSTALL${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  Are you absolutely sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
      echo -e "\nStopping services..."
      systemctl stop ws-proxy@* server-sldns badvpn hysteria-server hysteria2-server udp-custom zivpn openvpn-gateway openvpn-tcp openvpn-udp openvpn-nat sslh stunnel4 squid dropbear nginx haproxy xray 2>/dev/null || true
      systemctl disable ws-proxy@* server-sldns badvpn hysteria-server hysteria2-server udp-custom zivpn openvpn-gateway openvpn-tcp openvpn-udp openvpn-nat haproxy xray 2>/dev/null || true
      [ -x /usr/local/libexec/openvpn-nat ] && /usr/local/libexec/openvpn-nat stop 2>/dev/null || true
      sed -i '/^\[openvpn-tunnelguard\]$/,/^TIMEOUTclose = 0$/d' /etc/stunnel/stunnel.conf 2>/dev/null || true
      while iptables -C INPUT -p udp --dport 36713 -j ACCEPT 2>/dev/null; do iptables -D INPUT -p udp --dport 36713 -j ACCEPT; done
      netfilter-persistent save >/dev/null 2>&1 || true
      echo "Deleting files..."
      rm -f /etc/systemd/system/ws-proxy@.service /etc/systemd/system/server-sldns.service /etc/systemd/system/badvpn.service /etc/systemd/system/xray.service
      rm -f /etc/systemd/system/udp-custom.service /etc/systemd/system/zivpn.service /etc/systemd/system/zivpn-nat.service /etc/systemd/system/hysteria2-server.service /etc/systemd/system/openvpn-tcp.service /etc/systemd/system/openvpn-udp.service /etc/systemd/system/openvpn-gateway.service /etc/systemd/system/openvpn-nat.service
      rm -f /etc/cron.d/service-checker /etc/cron.d/logrotate /etc/cron.d/xray-expiry /etc/cron.d/hysteria-expiry /etc/cron.d/hysteria2-expiry /etc/cron.d/zivpn-expiry /etc/cron.d/openvpn-expiry /etc/sysctl.d/99-freenet-tuning.conf /etc/security/limits.d/99-freenet.conf
      rm -f /usr/local/bin/xray /usr/local/sbin/xray-install-version /usr/local/bin/exp-check /usr/local/bin/hysteria2 /usr/local/bin/hysteria2-exp /usr/local/libexec/hysteria2-auth /usr/local/libexec/openvpn-auth /usr/local/libexec/openvpn-userctl /usr/local/libexec/openvpn-nat
      rm -f /etc/letsencrypt/renewal-hooks/pre/xray-stop.sh /etc/letsencrypt/renewal-hooks/deploy/xray-cert.sh /etc/letsencrypt/renewal-hooks/post/xray-start.sh
      rm -rf /etc/deekayvpn /etc/slowdns /etc/socksproxy /etc/xray /etc/hysteria /etc/hysteria2 /etc/zivpn /etc/openvpn /etc/haproxy/haproxy.cfg /etc/haproxy/certs /etc/systemd/system/haproxy.service.d /root/udp /usr/local/bin/menu /usr/bin/menu /usr/bin/Menu
      systemctl daemon-reload; sysctl --system >/dev/null 2>&1 || true
      echo -e "${GREEN}✔ Removal complete.${NC}"
  else echo "Cancelled."; fi
  pause_return
}

# --- Main Dashboard ---
draw_header() {
  local os_name=$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')
  local os_ver=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")
  local os="${os_name} ${os_ver}"
  local arch=$(uname -m)
  local cores=$(cpu_count)
  local ip=$(server_ip)
  local time=$(date '+%H:%M %Z')
  local status=$(server_status)
  local ram=$(ram_percent)
  local cpu=$(cpu_percent)
  local buf=$(buffer_mem)

  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}Guruz GH${NC}${BLUE}  ✸  ${YELLOW}${BOLD}Plus${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} ${YELLOW}%s${NC}\n" "OS:" "$os" "Arch:" "$arch" "Cores:" "$cores"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} %s\n" "IP:" "$ip" "Time:" "$time" "Status:" "$status"
  echo -e "${CYAN}------------------------ ${BOLD}PROTOCOL PORTS${NC} ${CYAN}------------------------${NC}"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSH:" "22, 299" "System-DNS:" "53"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "Dropbear:" "80" "WEB-Nginx:" "85"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSL:" "443" "SSL/PYTHON:" "443"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "80, 8080, 8880" "Squid:" "3128, 8000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "2082, 2086" "BadVPN:" "7300"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "XRAY TLS:" "443" "XRAY NTLS:" "80, 8080, 8880"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "Hysteria 1:" "20000-50000" "Hysteria 2:" "36713/UDP"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "UDPCustom:" "1-65535" "ZiVPN:" "6000-19999"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "OpenVPN:" "1194 TCP/UDP" "OVPN SSL/PY:" "8443 / 8081"
  echo -e "${CYAN}----------------------- ${BOLD}SYSTEM RESOURCES${NC} ${CYAN}-----------------------${NC}"
  printf "  ${WHITE}%-10s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-10s${NC} ${YELLOW}%-10s${NC} ${WHITE}%-8s${NC} ${YELLOW}%s${NC}\n" "RAM Used:" "$ram" "CPU Used:" "$cpu" "Buffer:" "$buf"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear; draw_header; echo
  echo -e "  [${YELLOW}01${NC}] SSH Account Management (Legacy & UDP Custom)"
  echo -e "  [${YELLOW}02${NC}] Xray Account Management (VLESS)"
  echo -e "  [${YELLOW}03${NC}] Hysteria 1 Account Management (UDP)"
  echo -e "  [${YELLOW}04${NC}] ZiVPN Account Management (UDP)"
  echo -e "  [${YELLOW}05${NC}] Monitor Active Connections"
  echo -e "  [${YELLOW}06${NC}] Service Controls (Restart Protocols)"
  echo -e "  [${YELLOW}07${NC}] Backup & Restore Data"
  echo -e "  [${YELLOW}08${NC}] System Utilities (BBR & Netflix)"
  echo -e "  [${YELLOW}09${NC}] Advanced Settings (Domain / Nameserver)"
  echo -e "  [${YELLOW}10${NC}] Reboot Server"
  echo -e "  [${YELLOW}11${NC}] Hysteria 2 Account Management (UDP)"
  echo -e "  [${YELLOW}12${NC}] OpenVPN Account Management (OpenVPN3)"
  echo -e "  [${RED}00${NC}] Exit\n"
  read -rp "  ► Select an option: " opt
  case "$opt" in
    1|01) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}SSH ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Create SSH User\n  [${YELLOW}2${NC}] Extend User Expiry\n  [${YELLOW}3${NC}] Delete SSH User\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}XRAY ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Xray Account\n  [${YELLOW}2${NC}] Renew Xray Account\n  [${YELLOW}3${NC}] Delete Xray Account\n  [${YELLOW}4${NC}] Show Config Links\n  [${YELLOW}5${NC}] Force Delete Expired Xray Users Now\n  [${YELLOW}6${NC}] Update Xray Core Version\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub
        case "$sub" in
          1) add_xray ;;
          2) renew_xray ;;
          3) del_xray ;;
          4) show_xray ;;
          5) if /usr/local/bin/exp-check; then echo "Expired Xray users checked."; else echo -e "${RED}Xray expiry check failed.${NC}"; fi; pause_return ;;
          6)
            XRAY_VER="v26.3.27"
            echo "Installing verified Xray Core ${XRAY_VER}..."
            xray_rollback=$(mktemp /tmp/xray-binary.XXXXXX) || xray_rollback=""
            if [ -n "$xray_rollback" ]; then
              cp -p /usr/local/bin/xray "$xray_rollback" || { rm -f "$xray_rollback"; xray_rollback=""; }
            fi
            if /usr/local/sbin/xray-install-version "$XRAY_VER" && systemctl restart xray; then
              echo -e "${GREEN}✔ Xray updated to ${XRAY_VER}.${NC}"
            else
              if [ -n "$xray_rollback" ] && [ -s "$xray_rollback" ]; then
                install -m 755 "$xray_rollback" /usr/local/bin/xray
                systemctl restart xray || true
              fi
              echo -e "${RED}Xray update failed; review the error above.${NC}"
            fi
            [ -n "$xray_rollback" ] && rm -f "$xray_rollback"
            pause_return
            ;;
          0) break ;;
        esac
      done ;;
    3|03)
      while true; do
        clear; echo -e "${CYAN}HYSTERIA 1 ACCOUNT MANAGEMENT${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Hysteria 1 Account\n  [${YELLOW}2${NC}] Renew Hysteria 1 Account\n  [${YELLOW}3${NC}] Delete Hysteria 1 Account\n  [${YELLOW}4${NC}] List Hysteria 1 Accounts\n  [${YELLOW}5${NC}] Edit Hysteria 1 Speeds\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_hysteria;; 2) extend_hysteria;; 3) del_hysteria;; 4) list_hysteria;; 5) speed_hysteria;; 0) break;; esac
      done ;;
    4|04)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}ZIVPN ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add ZiVPN Account\n  [${YELLOW}2${NC}] Renew ZiVPN Account\n  [${YELLOW}3${NC}] Delete ZiVPN Account\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_zivpn;; 2) extend_zivpn;; 3) del_zivpn;; 4) list_zivpn;; 0) break;; esac
      done ;;
    5|05) online_users ;;
    6|06) service_control_menu ;;
    7|07)
      clear; echo -e "  [1] Backup System Configs\n  [2] Restore From Backup\n  [0] Back"
      read -rp " Select: " subopt; case "$subopt" in 1) backup_snapshot;; 2) restore_snapshot;; esac ;;
    8|08) utilities_menu ;;
    9|09) advanced_menu ;;
    10) clear; read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    11)
      while true; do
        clear; echo -e "${CYAN}HYSTERIA 2 ACCOUNT MANAGEMENT${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Hysteria 2 Account\n  [${YELLOW}2${NC}] Renew Hysteria 2 Account\n  [${YELLOW}3${NC}] Delete Hysteria 2 Account\n  [${YELLOW}4${NC}] List Hysteria 2 Accounts\n  [${YELLOW}5${NC}] Show Hysteria 2 Link\n  [${YELLOW}6${NC}] Remove Expired Hysteria 2 Users\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_hysteria2;; 2) extend_hysteria2;; 3) del_hysteria2;; 4) list_hysteria2;; 5) show_hysteria2;; 6) /usr/local/bin/hysteria2-exp; pause_return;; 0) break;; esac
      done ;;
    12)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "                 ${BOLD}OPENVPN ACCOUNT MANAGEMENT${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Create OpenVPN Account\n  [${YELLOW}2${NC}] Renew OpenVPN Account\n  [${YELLOW}3${NC}] Reset OpenVPN Password\n  [${YELLOW}4${NC}] Delete OpenVPN Account\n  [${YELLOW}5${NC}] List OpenVPN Accounts\n  [${YELLOW}6${NC}] Show Generator Details\n  [${YELLOW}7${NC}] Show Generic .ovpn Profile\n  [${YELLOW}8${NC}] Remove Expired OpenVPN Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub
        case "$sub" in
          1) add_openvpn ;;
          2) renew_openvpn ;;
          3) reset_openvpn_password ;;
          4) delete_openvpn ;;
          5) list_openvpn ;;
          6) show_openvpn_generator ;;
          7) show_openvpn_profile ;;
          8) /usr/local/libexec/openvpn-userctl cleanup; echo -e "${GREEN}Expired OpenVPN accounts removed.${NC}"; pause_return ;;
          0) break ;;
        esac
      done ;;
    0|00) clear; exit 0 ;;
  esac
done
EOF_MENU

sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu

# Finishing
chown -R www-data:www-data /home/vps/public_html
clear
figlet GuruzGH Script -c | lolcat
echo "       Installation Complete! System need to reboot to apply all changes! "
history -c; rm /root/full.sh 2>/dev/null || true
echo "           Server will reboot in 10 seconds! "
sleep 10
reboot
