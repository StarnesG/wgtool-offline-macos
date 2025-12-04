#!/bin/bash
# wg-control.sh  ––  启停隧道
CONF_DIR="/usr/local/etc/wireguard"
IFACE="${2:-wg0}"
CONF="$CONF_DIR/$IFACE.conf"

case "$1" in
  up)
    WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go /usr/local/bin/wg-quick up "$CONF"
    ;;
  down)
    WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go /usr/local/bin/wg-quick down "$CONF"
    ;;
  restart)
    $0 down "$IFACE" && sleep 1 && $0 up "$IFACE"
    ;;
  *)
    echo "Usage: $0 up|down|restart [conf-name]"
    exit 1
    ;;
esac