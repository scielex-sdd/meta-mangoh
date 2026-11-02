# Cypress WiFi on mangOH Yellow: firmware, the cywifi script Legato's WiFi service calls, and the
# tools to run WiFi from Linux directly.
IMAGE_INSTALL_append = " brcmfmac43430-support kernel-module-brcmfmac wpa-supplicant iw"
