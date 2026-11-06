# Attach the Cypress chip's Bluetooth whenever its USB-UART appears. mdev takes the first rule that
# matches, so this one goes before Sierra's for tty.*.

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append = " file://ttyUSB.sh"

do_install_append() {
    install -m 0755 ${WORKDIR}/ttyUSB.sh ${D}${sysconfdir}/mdev/ttyUSB.sh
    sed -i '/^tty\.\* /i ttyUSB[0-9]+ 0:0 0620 */etc/mdev/ttyUSB.sh' ${D}${sysconfdir}/mdev.conf
}
