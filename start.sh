#!/bin/sh
set -eu
export LC_ALL=C
umask 077
cd /data

USERNAME=${USERNAME:-warp}
PASSWORD=${PASSWORD:?PASSWORD is required}
case "$USERNAME$PASSWORD" in
    *[[:space:]]*) echo 'Credentials cannot contain whitespace' >&2; exit 1 ;;
esac
[ "${#USERNAME}" -le 255 ] && [ "${#PASSWORD}" -le 255 ] || {
    echo 'Credentials must be at most 255 bytes' >&2; exit 1;
}

# Docker can retain our resolver file across restarts. Bootstrap without WARP.
mkdir -p /run/warp-socks
UDP_PUBLIC_IP=${UDP_PUBLIC_IP:-}
if [ -n "$UDP_PUBLIC_IP" ]; then
    printf '%s\n' "$UDP_PUBLIC_IP" | awk -F. '
        NR != 1 || NF != 4 {exit 1}
        {for (i=1; i<=4; i++) if ($i !~ /^[0-9]+$/ || length($i)>3 || $i>255) exit 1}
    ' || { echo 'UDP_PUBLIC_IP must be an IPv4 address' >&2; exit 1; }
fi
sed "s/udp-public-address-v4: ''/udp-public-address-v4: '$UDP_PUBLIC_IP'/" \
    /etc/hev.yml > /run/warp-socks/hev.yml
if [ -f /run/warp-socks/resolv.original ]; then
    cat /run/warp-socks/resolv.original > /etc/resolv.conf
else
    cp /etc/resolv.conf /run/warp-socks/resolv.original
fi
GENERATE=0
if [ ! -s wgcf-profile.conf ]; then
    [ -s wgcf-account.toml ] || wgcf register --accept-tos
    GENERATE=1
fi
if [ -n "${LICENSE_KEY:-}" ]; then
    [ -s wgcf-account.toml ] || {
        echo 'LICENSE_KEY requires the original wgcf-account.toml in /data' >&2; exit 1;
    }
    wgcf update --license-key "$LICENSE_KEY"
    GENERATE=1
fi
if [ "$GENERATE" = 1 ]; then
    wgcf generate --keepalive=25 --profile wgcf-profile.conf.tmp
    mv wgcf-profile.conf.tmp wgcf-profile.conf
fi
chmod 600 wgcf-profile.conf
[ ! -e wgcf-account.toml ] || chmod 600 wgcf-account.toml

# wg-quick loads both addresses and routes. Ignore imported hooks/DNS settings.
awk -v endpoint="${WARP_ENDPOINT:-}" '
    /^\[Interface\]$/ {section=1; print; print "Table = 51820"; next}
    /^\[Peer\]$/ {section=2; print; next}
    section==1 && /^[[:space:]]*(PrivateKey|Address|MTU)[[:space:]]*=/ {print}
    section==2 && /^[[:space:]]*Endpoint[[:space:]]*=/ && endpoint!="" {
        print "Endpoint = " endpoint; next
    }
    section==2 && /^[[:space:]]*(PublicKey|PresharedKey|AllowedIPs|Endpoint|PersistentKeepalive)[[:space:]]*=/ {print}
' wgcf-profile.conf > /run/warp-socks/warp.conf
wg-quick up /run/warp-socks/warp.conf
ip -4 addr show dev warp | grep -q 'inet '
ip -6 addr show dev warp scope global | grep -q 'inet6 '

# Only sockets bound to warp and our DNS resolvers use the tunnel table.
# Unreachable routes prevent fallback even if the interface is removed.
for family in -4 -6; do
    ip "$family" route add unreachable default metric 32767 table 51820
    ip "$family" rule add priority 100 oif warp table 51820
done
ip -4 rule add priority 90 to 1.1.1.1/32 table 51820
ip -4 rule add priority 90 to 1.0.0.1/32 table 51820
printf 'nameserver 1.1.1.1\nnameserver 1.0.0.1\noptions timeout:2 attempts:2\n' > /etc/resolv.conf

printf '%s %s 0\n' "$USERNAME" "$PASSWORD" > /run/warp-socks/auth.txt
echo "[warp-socks] SOCKS5 listening on TCP :1080"
exec hev-socks5-server /run/warp-socks/hev.yml
