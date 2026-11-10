SUMMARY = "Turn on the CYW20719's SECI link, so WiFi and Bluetooth share the antenna"
DESCRIPTION = "For a mangOH Yellow with R301 and R303 removed. Not part of the image by default."
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MPL-2.0;md5=815ca599c9df247a0c7f619bab123dad"

RDEPENDS_${PN} = "bluez5 iw"

SRC_URI = "file://cyw20719-enable-seci.sh"

do_install() {
    install -D -m 0755 ${WORKDIR}/cyw20719-enable-seci.sh ${D}${sbindir}/cyw20719-enable-seci.sh
}

FILES_${PN} = "${sbindir}/cyw20719-enable-seci.sh"
