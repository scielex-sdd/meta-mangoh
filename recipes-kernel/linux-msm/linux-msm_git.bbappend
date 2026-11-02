# mangOH Yellow: the Cypress CYW43430 WiFi on the WP's SDIO port (sdhc_2).
#
# The device tree patch powers the chip through WL_REG_ON (GPIO 1 of the SX1509 expander) as the
# SDIO slot's supply, so the kernel powers it before scanning the bus and owns the line from then
# on. The in-kernel brcmfmac driver replaces the old backports build.

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-arm64-dts-mangoh-yellow-power-the-Cypress-WiFi-on-sdhc_2.patch"

KBUILD_DEFCONFIG_SNIPPETS_append := " ${THISDIR}/files/brcmfmac.cfg"

# Load the driver at boot so wlan0 exists before Legato's WiFi service starts.
KERNEL_MODULE_AUTOLOAD += "brcmfmac"
