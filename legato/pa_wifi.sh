#!/bin/sh
# Copyright (C) Sierra Wireless Inc.
#
# Cypress Wifi PA for the mangOH platform
#
# ($1:) -d Debug logs
# $1: Command (ex:  WIFI_START
#                   WIFICLIENT_CONNECT
# $2: wpa_supplicant.conf file directory

if [ "$1" = "-d" ]; then
    shift
    set -x
fi

CMD=$1
# WiFi interface
IFACE=wlan0
# If WLAN interface exists but can not be brought up, means WiFi hardware is inserted,
# drivers are loaded successfully, but firmware failed to boot, tiwifi.sh returns 100
FIRMWAREFAILURE=100
# If WLAN interface does not exist but driver is installed, means WiFi hardware is absent
HARDWAREABSENCE=50
# WiFi driver is not installed
NODRIVER=100
TIMEOUT=8
# PATH
export PATH=/legato/systems/current/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
INITSCRIPT=/etc/init.d/cywifi
# Country for the firmware's channels and power limits: XV, Broadcom's worldwide code, so the
# modem may transmit anywhere (it only listens on the channels some countries do not allow)
COUNTRY=XV

# $1 as 16 or 32 bit little endian binary
Le16()
{
    printf "$(printf '\\%03o\\%03o' $(($1 & 255)) $(($1 >> 8 & 255)))"
}

Le32()
{
    Le16 $(($1 & 65535))
    Le16 $(($1 >> 16 & 65535))
}

# Send a firmware command through brcmfmac's vendor command (BRCMF_VNDR_CMDS_DCMD)
# $1: command, $2: 1 to set, $3: file with the command's data
FirmwareCommand()
{
    { Le32 $1; Le32 $(wc -c < $3); Le32 20; Le32 $2; Le32 0; cat $3; } > /tmp/pa_wifi_cmd.bin
    /usr/sbin/iw dev ${IFACE} vendor send 0x001018 0x1 /tmp/pa_wifi_cmd.bin >/dev/null
}

# Set the firmware's country. The kernel's brcmfmac loads the firmware's country data (CLM blob)
# when it starts the chip, but leaves the country at the NVRAM's (ccode=ALL).
WiFiRegulatory()
{
    { printf 'country\000%s\000\000' ${COUNTRY}; Le32 0; printf '%s\000\000' ${COUNTRY}; } > /tmp/pa_wifi_data.bin
    FirmwareCommand 263 1 /tmp/pa_wifi_data.bin || return 127    # WLC_SET_VAR
    rm -f /tmp/pa_wifi_cmd.bin /tmp/pa_wifi_data.bin
}

# Create the WiFi network interface, with the firmware's country
WiFiStart()
{
    $INITSCRIPT start || return $?
    WiFiRegulatory
}

# Check the connection on the WiFi network interface.
# Exit with 0 if connected otherwise exit with 8 (time out)
CheckConnection()
{
    retries=10
    echo "Checking connection..."
    # Verify connection status
    for i in $(seq 1 ${retries})
    do
      echo "loop=${i}"
      # Connected (also on the last try, which used to be reported as a time out)
      (/usr/sbin/iw $1 link | grep "Connected to") && exit 0
      sleep 1
    done
    # Connection request time out.
    exit ${TIMEOUT}
}

WiFiReset()
{
    retries=3
    echo "WiFi reset"
    for i in $(seq 1 ${retries})
    do
      sleep 1
      $INITSCRIPT stop
      sleep 1
      WiFiStart && exit 0
    done
    exit 127
}

case ${CMD} in
  WIFI_START)
    echo "WIFI_START"
    # Create the WiFi network interface
    WiFiStart && exit 0
    # Store failure reason
    FAILUREREASON=$?
    # If cywifi.sh indicates firmware fails to boot, do reset
    if [ ${FAILUREREASON} -eq ${FIRMWAREFAILURE} ]; then
        WiFiReset && exit 0
        # Reset fail, do clean up
        $INITSCRIPT stop
        exit ${FAILUREREASON}
    fi
    # Hardware is absent, do clean up
    if [ ${FAILUREREASON} -eq ${HARDWAREABSENCE} ]; then
        $INITSCRIPT stop
        exit ${FAILUREREASON}
    fi
    # Other reasons, do clean up also
    $INITSCRIPT stop
    exit ${FAILUREREASON} ;;

  WIFI_STOP)
    echo "WIFI_STOP"
    # If wpa_supplicant is still running, terminate it
    (/bin/ps -ax | grep wpa_supplicant | grep ${IFACE} >/dev/null 2>&1) \
    && /sbin/wpa_cli -i${IFACE} terminate
    # Delete the WiFi network interface
    $INITSCRIPT stop || exit 127
    exit 0 ;;

  WIFI_SET_EVENT)
    echo "WIFI_SET_EVENT"
    /usr/sbin/iw event || exit 127
    exit 0 ;;

  WIFI_UNSET_EVENT)
    echo "WIFI_UNSET_EVENT"
    count=$(/usr/bin/pgrep -c iw)
    [ "${count}" -eq 0 ] && exit 0
    for i in $(seq 1 ${count})
    do
      pid=$(/usr/bin/pgrep -n iw)
      /bin/kill -9 ${pid}
    done
    count=$(/usr/bin/pgrep -c iw)
    [ "${count}" -eq 0 ] || exit 127
    exit 0 ;;

  WIFI_CHECK_HWSTATUS)
    echo "WIFI_CHECK_HWSTATUS"
    #Client request disconnection if interface in up
    /sbin/ifconfig | grep ${IFACE} >/dev/null
    [ $? -eq 0 ] && exit 0
    sleep 1
    #Check WiFi stop called or not
    /sbin/lsmod | grep brcmfmac >/dev/null
    #Driver stays, hardware removed
    [ $? -eq 0 ] && exit ${HARDWAREABSENCE}
    #WiFi stop called
    exit ${NODRIVER} ;;

  # Link data (signal, RX, TX) for le_wifiClient_GetCurrentSignalStrength() and friends,
  # which Legato 21.05 asks for (the TI script has it; this one, from 19.11, did not)
  WIFI_GET_DATA)
    echo "WIFI_GET_DATA"
    /usr/sbin/iw ${IFACE} link || exit 127
    exit 0 ;;

  WIFIAP_HOSTAPD_START)
    echo "WIFIAP_HOSTAPD_START"
    (/bin/hostapd /tmp/hostapd.conf -i${IFACE} -B) && exit 0
    # Fail to start hostapd, do cleanup
    $INITSCRIPT stop
    exit 127 ;;

  WIFIAP_HOSTAPD_STOP)
    echo "WIFIAP_HOSTAPD_STOP"
    rm -f /tmp/dnsmasq.wlan.conf
    touch /tmp/dnsmasq.wlan.conf
    /etc/init.d/dnsmasq stop
    killall hostapd
    sleep 1;
    pidof hostapd && (kill -9 `pidof hostapd` || exit 127)
    pidof dnsmasq && (kill -9 `pidof dnsmasq` || exit 127)
    /etc/init.d/dnsmasq start || exit 127
    exit 0 ;;

  WIFIAP_WLAN_UP)
    echo "WIFIAP_WLAN_UP"
    AP_IP=$2
    /sbin/ifconfig | grep ${IFACE} || exit 127
    /sbin/ifconfig ${IFACE} ${AP_IP} up || exit 127
    exit 0 ;;

  DNSMASQ_RESTART)
    echo "interface=${IFACE}" >> /tmp/dnsmasq.wlan.conf
    /etc/init.d/dnsmasq stop
    pkill -9 dnsmasq
    /etc/init.d/dnsmasq start || exit 127
    exit 0 ;;

  WIFICLIENT_START_SCAN)
    echo "WIFICLIENT_START_SCAN"
    (/usr/sbin/iw dev ${IFACE} scan | grep 'BSS\|SSID\|signal') || exit 127
    exit 0 ;;

  WIFICLIENT_CONNECT)
    echo "WIFICLIENT_CONNECT"
    WPA_CFG=$2
    [ -f ${WPA_CFG} ] || exit 127
    # wpa_supplicant is running, return duplicated request
    /bin/ps -A | grep wpa_supplicant && exit 14
    /sbin/wpa_supplicant -d -Dnl80211 -c ${WPA_CFG} -i${IFACE} -B || exit 127
    CheckConnection ${IFACE} ;;

  WIFICLIENT_DISCONNECT)
    echo "WIFICLIENT_DISCONNECT"
    /sbin/wpa_cli -i${IFACE} terminate || exit 127
    echo "WiFi client disconnected."
    exit 0 ;;

  IPTABLE_DHCP_INSERT)
    echo "IPTABLE_DHCP_INSERT"
    /usr/sbin/iptables -I INPUT -i ${IFACE} -p udp -m udp \
     --sport 67:68 --dport 67:68 -j ACCEPT  || exit 127
    exit 0 ;;

  IPTABLE_DHCP_DELETE)
    echo "IPTABLE_DHCP_DELETE"
    /usr/sbin/iptables -D INPUT -i ${IFACE} -p udp -m udp \
     --sport 67:68 --dport 67:68 -j ACCEPT  || exit 127
    exit 0 ;;

  *)
    echo "Parameter not valid"
    exit 127 ;;
esac

