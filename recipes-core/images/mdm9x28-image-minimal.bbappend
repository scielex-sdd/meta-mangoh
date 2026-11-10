# Cypress WiFi on mangOH Yellow: firmware, the cywifi script Legato's WiFi service calls, and the
# tools to run WiFi from Linux directly.
IMAGE_INSTALL_append = " brcmfmac43430-support kernel-module-brcmfmac wpa-supplicant iw"

# Bluetooth: BlueZ, and the kernel's drivers for the Cypress chip's USB-UART.
IMAGE_INSTALL_append = " bluez5 kernel-module-hci-uart kernel-module-ftdi-sio"

# MANGOH_YELLOW_SECI = "y": WiFi and Bluetooth share the antenna, the Bluetooth half (the WiFi half is in
# brcmfmac43430-support). Needs R301 and R303 removed.
IMAGE_INSTALL_append = "${@bb.utils.contains('MANGOH_YELLOW_SECI', 'y', ' cyw20719-support', '', d)}"

# Drivers of the board's I2C devices: IMU, environmental sensor, light sensor, fuel gauge, charger and RTC.
IMAGE_INSTALL_append = " kernel-module-bmi160-i2c kernel-module-bme680-i2c kernel-module-opt3001 kernel-module-bq27xxx-battery-i2c kernel-module-bq256xx-charger kernel-module-rtc-pcf85063"
