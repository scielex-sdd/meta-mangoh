#!/bin/sh
# mdev runs this for each ttyUSB device, as it comes and goes. The USB-UART on port 2 of the mangOH
# Yellow's USB hub goes to the Cypress chip's Bluetooth: attach it as an HCI controller for BlueZ,
# and turn on its link to the WiFi chip where the image has that.

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# mdev comes here for the USB-serial device and again for its tty: act on the tty's alone.
case "$DEVPATH" in
    */1-1.2:1.0/*/tty/*) ;;
    *) exit 0 ;;
esac

PIDFILE=/run/btattach.$MDEV.pid

case "$ACTION" in
    add)
        modprobe hci_uart
        btattach -P h4 -B /dev/$MDEV >/dev/null 2>&1 &
        echo $! > $PIDFILE
        [ -x /usr/sbin/cyw20719-enable-seci.sh ] && /usr/sbin/cyw20719-enable-seci.sh >/dev/null 2>&1 &
        ;;
    remove)
        if [ -f $PIDFILE ] ; then
            kill $(cat $PIDFILE)
            rm -f $PIDFILE
        fi
        ;;
esac

exit 0
