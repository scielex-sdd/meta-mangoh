# mangOH Yellow: the Cypress CYW43430 WiFi on the WP's SDIO port (sdhc_2), and the board's I2C devices.
#
# The device tree patch powers the chip through WL_REG_ON (GPIO 1 of the SX1509 expander) as the
# SDIO slot's supply, so the kernel powers it before scanning the bus and owns the line from then
# on. The in-kernel brcmfmac driver replaces the old backports build.

FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-arm64-dts-mangoh-yellow-power-the-Cypress-WiFi-on-sdhc_2.patch \
            file://0002-arm64-dts-mangoh-yellow-describe-the-board-s-I2C-devices.patch \
            file://0003-iio-opt3001-add-the-OPT3002.patch \
            file://0004-power-supply-bq27xxx-add-the-BQ27426.patch \
            file://0005-iio-chemical-add-the-BME680.patch \
            file://0006-power-supply-add-the-BQ256XX-charger.patch \
           "

# DV3 boards have WL_REG_ON on WP GPIO33. Nothing can choose a regulator's GPIO at run time, so a DV3
# image is built on purpose: MANGOH_YELLOW_REV = "dv3" in conf/local.conf.
SRC_URI += "${@bb.utils.contains('MANGOH_YELLOW_REV', 'dv3', 'file://0007-arm64-dts-mangoh-yellow-WL_REG_ON-on-GPIO33-for-DV3-boards.patch', '', d)}"

KBUILD_DEFCONFIG_SNIPPETS_append := " ${THISDIR}/files/brcmfmac.cfg ${THISDIR}/files/mangoh-yellow-sensors.cfg"

# Load the driver at boot so wlan0 exists before Legato's WiFi service starts.
KERNEL_MODULE_AUTOLOAD += "brcmfmac"

# The drivers of the board's I2C devices. The RTC's stays a module so that it comes up as rtc1,
# after the PMIC's rtc0, which sets the system clock at boot.
KERNEL_MODULE_AUTOLOAD += "bmi160_i2c bme680_i2c opt3001 bq27xxx_battery_i2c bq256xx_charger rtc-pcf85063"
