DESCRIPTION = "Support files for the Cypress WiFi on mangOH Yellow"
HOMEPAGE = "https://mangoh.io"
LICENSE = "MPL-2.0"
LIC_FILES_CHKSUM = "file://../cywifi.sh;startline=2;endline=2;md5=4ab7b147102bbb17e696589e8e19383e"

# The in-kernel driver (kernel 4.14) replaces the old backports build.
RDEPENDS_${PN} += "kernel-module-brcmfmac"

FILES_${PN} = " \
    ${base_libdir}/firmware/brcm/brcmfmac43430-sdio.bin \
    ${base_libdir}/firmware/brcm/brcmfmac43430-sdio.clm_blob \
    ${base_libdir}/firmware/brcm/brcmfmac43430-sdio.txt \
    ${sysconfdir}/init.d/cywifi \
    "

SRC_URI = " \
    file://brcmfmac43430-sdio.bin \
    file://brcmfmac43430-sdio.clm_blob \
    file://brcmfmac43430-sdio.txt \
    file://cywifi.sh \
    "

do_install() {
    install -D -m 0644 ${WORKDIR}/brcmfmac43430-sdio.bin \
        ${D}${base_libdir}/firmware/brcm/brcmfmac43430-sdio.bin
    install -D -m 0644 ${WORKDIR}/brcmfmac43430-sdio.clm_blob \
        ${D}${base_libdir}/firmware/brcm/brcmfmac43430-sdio.clm_blob
    install -D -m 0644 ${WORKDIR}/brcmfmac43430-sdio.txt \
        ${D}${base_libdir}/firmware/brcm/brcmfmac43430-sdio.txt
    install -D -m 0755 ${WORKDIR}/cywifi.sh ${D}${sysconfdir}/init.d/cywifi

    # MANGOH_YELLOW_SECI = "y": WiFi and Bluetooth share the antenna, the WiFi half (cyw20719-support is the
    # Bluetooth half). btcxwarflags bit 0 lets the firmware move the antenna switch on GPIO_4 for Bluetooth.
    # Undocumented: found in a WICED NVRAM for the 43364, and measured here. btc_mode=5 gave WiFi the least
    # added delay of the modes measured, with Bluetooth's signal unchanged. The NVRAM file has CRLF line ends.
    if ${@bb.utils.contains('MANGOH_YELLOW_SECI', 'y', 'true', 'false', d)}; then
        printf '\r\nbtcxwarflags=0x1\r\nbtc_mode=5\r\n' >> ${D}${base_libdir}/firmware/brcm/brcmfmac43430-sdio.txt
    fi
}
