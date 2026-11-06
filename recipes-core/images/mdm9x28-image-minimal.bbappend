# Cypress WiFi on mangOH Yellow: firmware, the cywifi script Legato's WiFi service calls, and the
# tools to run WiFi from Linux directly.
IMAGE_INSTALL_append = " brcmfmac43430-support kernel-module-brcmfmac wpa-supplicant iw"

# Bluetooth: BlueZ, and the kernel's drivers for the Cypress chip's USB-UART.
IMAGE_INSTALL_append = " bluez5 kernel-module-hci-uart kernel-module-ftdi-sio"

# Drivers of the board's I2C devices: IMU, environmental sensor, light sensor, fuel gauge, charger and RTC.
IMAGE_INSTALL_append = " kernel-module-bmi160-i2c kernel-module-bme680-i2c kernel-module-opt3001 kernel-module-bq27xxx-battery-i2c kernel-module-bq256xx-charger kernel-module-rtc-pcf85063"
