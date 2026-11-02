#!/bin/bash
# ==============================================================================
# Kali Linux Wi-Fi 6 Master AP & Rogue AP Configurator for Orange Pi 4 Pro
# Hardware: AIC8800D80 Dual-Band Wi-Fi 6 / BT 5.4 (Allwinner A733 / sun60iw2)
# ==============================================================================
set -e

IFACE="wlan0"
SSID="${1:-Kali_WiFi6_AP}"
PASSPHRASE="${2:-KaliLinux2026}"
BAND="${3:-5g}"
CHANNEL="${4:-36}"
ROGUE_MODE="${5:-normal}" # "normal", "rogue", "open"

echo "========================================================================"
echo " Kali Linux Wi-Fi 6 (802.11ax) Master & Pentest AP: Orange Pi 4 Pro"
echo " SSID: $SSID"
echo " Band: $BAND | Channel: $CHANNEL | Mode: $ROGUE_MODE"
echo " Interface: $IFACE"
echo "========================================================================"

# 1. Hardware Entitlement & Cryptographic SID Check
GUARD_SCRIPT="$(dirname "$0")/wifi6-ap-guard.sh"
if [ -f "$GUARD_SCRIPT" ]; then
    bash "$GUARD_SCRIPT"
elif [ -f "/usr/local/bin/wifi6-ap-guard.sh" ]; then
    bash "/usr/local/bin/wifi6-ap-guard.sh"
fi

# 2. Ensure required Kali packages
REQUIRED_PKGS="hostapd dnsmasq iptables iw wireless-tools"
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "Installing missing package: $pkg..."
        apt-get update -qq && apt-get install -y -qq "$pkg"
    fi
done

# 3. Prevent NetworkManager from interfering with AP interface on Kali
systemctl stop hostapd 2>/dev/null || true
if command -v nmcli >/dev/null 2>&1; then
    nmcli device set "$IFACE" managed no 2>/dev/null || true
fi
mkdir -p /etc/NetworkManager/conf.d
cat << 'NM_CONF' > /etc/NetworkManager/conf.d/99-unmanaged-wlan0.conf
[keyfile]
unmanaged-devices=interface-name:wlan0
NM_CONF
systemctl reload NetworkManager 2>/dev/null || true

# 4. Configure IP address on wlan0
ip link set "$IFACE" down 2>/dev/null || true
ip addr flush dev "$IFACE" 2>/dev/null || true
ip addr add 192.168.44.1/24 dev "$IFACE"
ip link set "$IFACE" up

# 5. Generate dnsmasq configuration (Supports captive portal / DNS spoof in rogue mode)
mkdir -p /etc/dnsmasq.d
if [ "$ROGUE_MODE" = "rogue" ]; then
    echo "[*] Activating Rogue AP DNS wildcard spoofing (all traffic -> 192.168.44.1)..."
    cat << DNSMASQ_CONF > /etc/dnsmasq.d/kali-wifi6-ap.conf
interface=$IFACE
bind-interfaces
dhcp-range=192.168.44.10,192.168.44.200,255.255.255.0,12h
dhcp-option=3,192.168.44.1
dhcp-option=6,192.168.44.1
address=/#/192.168.44.1
DNSMASQ_CONF
else
    cat << DNSMASQ_CONF > /etc/dnsmasq.d/kali-wifi6-ap.conf
interface=$IFACE
bind-interfaces
dhcp-range=192.168.44.10,192.168.44.200,255.255.255.0,24h
dhcp-option=3,192.168.44.1
dhcp-option=6,1.1.1.1,8.8.8.8
server=1.1.1.1
DNSMASQ_CONF
fi

systemctl restart dnsmasq

# 6. Determine hostapd band configuration
if [ "$BAND" = "2g" ]; then
    HW_MODE="g"
    DEFAULT_CHAN=6
    AX_PARAMS="ieee80211ax=1"
else
    HW_MODE="a"
    DEFAULT_CHAN=36
    AX_PARAMS="ieee80211n=1
ieee80211ac=1
ieee80211ax=1
he_su_beamformer=0
he_su_beamformee=1
he_mu_beamformer=0"
fi

if [ -z "$CHANNEL" ]; then
    CHANNEL=$DEFAULT_CHAN
fi

# 7. Generate hostapd configuration (Open or WPA2/WPA3)
if [ "$PASSPHRASE" = "open" ] || [ "$PASSPHRASE" = "none" ] || [ "$ROGUE_MODE" = "open" ]; then
    AUTH_CONF="auth_algs=1"
else
    AUTH_CONF="wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
auth_algs=1"
fi

cat << HOSTAPD_CONF > /etc/hostapd/hostapd.conf
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=$HW_MODE
channel=$CHANNEL
country_code=00
ieee80211d=1
$AX_PARAMS
$AUTH_CONF
wmm_enabled=1
HOSTAPD_CONF

sed -i 's|^#*DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# 8. Setup IPv4 forwarding and NAT to uplink (eth0 or end0)
sysctl -w net.ipv4.ip_forward=1 >/dev/null
WAN_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
if [ -n "$WAN_IFACE" ] && [ "$WAN_IFACE" != "$IFACE" ]; then
    iptables -t nat -C POSTROUTING -o "$WAN_IFACE" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
    iptables -C FORWARD -i "$IFACE" -o "$WAN_IFACE" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i "$IFACE" -o "$WAN_IFACE" -j ACCEPT
    iptables -C FORWARD -i "$WAN_IFACE" -o "$IFACE" -m state --state RELATED,ESTABLISHED 2>/dev/null || \
    iptables -A FORWARD -i "$WAN_IFACE" -o "$IFACE" -m state --state RELATED,ESTABLISHED
fi

# 9. Start hostapd
systemctl unmask hostapd 2>/dev/null || true
systemctl restart hostapd

echo "========================================================================"
echo " [✓] Kali Linux Wi-Fi 6 AP successfully launched!"
echo " SSID: $SSID"
echo " Gateway IP: 192.168.44.1 (Subnet: 192.168.44.0/24)"
echo " Status: $(systemctl is-active hostapd)"
echo "========================================================================"
