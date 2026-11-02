#!/bin/sh
# Copyright (C) Sierra Wireless Inc. Use of this work is subject to license.
#
# Broadcom/Cypress chip startup for mangOH Yellow (Release 15, kernel 4.14)
#
# The chip's power (WL_REG_ON, GPIO 1 of the SX1509 expander) and its SDIO slot (sdhc_2) are
# described in the device tree, so the kernel powers the chip, finds it on the bus and owns
# WL_REG_ON from then on. brcmfmac is loaded at boot. This script only brings wlan0 up and down
# for Legato's WiFi service, which calls it from pa_wifi.sh.
#
# Not handled: mangOH Yellow DV3 boards, which use WP GPIO33 for WL_REG_ON instead of the
# expander.

export PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin

cy_wifi_start() {
    # brcmfmac is normally already loaded (KERNEL_MODULE_AUTOLOAD); load it if not.
    if ! grep -q '^brcmfmac ' /proc/modules ; then
        modprobe brcmfmac || { echo "brcmfmac could not be loaded"; exit 2; }
    fi

    # The firmware loads and the chip restarts before wlan0 appears; wait up to 10 s.
    i=0
    while [ ! -d /sys/class/net/wlan0 ] && [ $i -lt 10 ] ; do
        sleep 1
        i=$((i + 1))
    done
    if [ ! -d /sys/class/net/wlan0 ] ; then
        echo "wlan0 interface was not created by Cypress drivers"; exit 100
    fi

    ifconfig wlan0 up >/dev/null
    if [ $? -ne 0 ] ; then
        echo "wlan0 interface UP not working"; exit 127
    fi
}

cy_wifi_stop() {
    # Leave the driver loaded and the chip powered: the kernel powers it down at shutdown.
    if [ -d /sys/class/net/wlan0 ] ; then
        ifconfig wlan0 down
    fi
}

case "$1" in
    start)
	cy_wifi_start
	;;
    stop)
	cy_wifi_stop
	;;
    restart)
	cy_wifi_stop
	cy_wifi_start
	;;
    *)
	exit 99
	;;
esac

exit 0
