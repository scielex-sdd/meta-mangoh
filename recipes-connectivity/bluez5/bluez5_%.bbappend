# BlueZ for the Cypress chip's Bluetooth, on its USB-UART (see recipes-core/initscripts).

# busybox init only runs rcS.d. After D-Bus (dbus_%.bbappend).
INITSCRIPT_PARAMS = "start 21 S . stop 79 S ."

# Not wanted here, and they bring large dependencies.
PACKAGECONFIG_remove = "mesh nfc obex-profiles"

# Sierra's layer adds the firmware of its own Bluetooth chip, a QCA9377.
RDEPENDS_${PN}_remove = "qca9377-bt-firmware"
