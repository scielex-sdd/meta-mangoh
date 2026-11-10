# meta-mangoh

A Yocto layer for the mangOH Yellow with a Sierra Wireless WP77xx (WP7702) module, for Sierra's
Release 15 Linux (SWI9X06Y_03.00.x: Yocto 3.1 "dunfell", kernel 4.14). The `release-15` branch is
a port of the original layer, which was written for Release 13 (Yocto 2.5, kernel 3.18).

## What it does

**Cypress CYW43364 WiFi.** The chip sits on the WP's SDIO port (`sdhc_2`). `brcmfmac` reports it as
a 43430, so its firmware files use that name.

- `recipes-kernel/linux-msm`: a device-tree patch to Sierra's `swi-wp-mangoh-yellow.dtsi` that
  describes WL_REG_ON (GPIO 1 of the SX1509 expander) as the SDIO slot's supply. The kernel
  powers the chip before it scans the bus and owns the line from then on. A config fragment
  builds the in-kernel `brcmfmac` driver as a module, loaded at boot. Two patches from Linux 4.15
  make the driver load the chip's CLM blob: without them the link drops about once a minute.
- `recipes-connectivity/brcmfmac43430-support`: the chip's firmware, its NVRAM file and CLM blob
  in `/lib/firmware/brcm/`, and `/etc/init.d/cywifi`, which Legato's WiFi service calls (through
  `legato/pa_wifi.sh`, below) to bring `wlan0` up and down.
- `recipes-core/images`: adds the firmware, the driver, `wpa-supplicant` and `iw` to the image.

**Bluetooth.** The module's CYW20719 (BLE) is behind the FT230X USB-UART on port 2 of the USB hub.

- `recipes-kernel/linux-msm`: the kernel's own Bluetooth and `hci_uart`, as modules, and `ftdi_sio` loaded
  at boot.
- `recipes-core/initscripts`: an mdev rule that runs `btattach -P h4 -B` on that USB-UART whenever it
  appears, so the controller comes up as `hci0`.
- `recipes-connectivity/bluez5`: BlueZ, started at boot.

The controller starts powered off: `bluetoothctl power on`.

**WiFi and Bluetooth share one antenna.** A switch on the module, steered by the WiFi chip's GPIO_4,
selects which radio has the antenna. The WiFi chip moves it as the two chips arbitrate over SECI. It
is off by default. It needs R301 and R303 removed: the board grounds the two SECI lines through them,
and nothing goes in their place. Then add this to `conf/local.conf` in the build directory:

    MANGOH_YELLOW_SECI = "y"

Set it only for boards with both removed. Nothing checks for them, and with them fitted the Bluetooth
chip would drive a grounded line.

- `recipes-connectivity/brcmfmac43430-support` adds `btcxwarflags=0x1` and `btc_mode=5` to the NVRAM
  file. `btcxwarflags` is undocumented: it was found in a WICED NVRAM for the 43364.
- `recipes-core/images` adds `recipes-connectivity/cyw20719-support`, whose script turns on the
  Bluetooth chip's side of the link when WiFi starts and when the controller is attached. It writes
  the chip's RAM only, and logs to the kernel log.

Without it, the antenna stays with WiFi while it is joined, and Bluetooth reads about 30 dB low.

**The board's I2C devices.** `recipes-kernel/linux-msm` describes them in the device tree and builds
their drivers as modules, loaded at boot. `i2c-0` to `i2c-3` are the channels of the I2C switch on
`i2c-4`. The drivers are mainline's, backported where kernel 4.14 lacks them; each patch says from where.

| Bus | Address | Device | Driver |
|---|---|---|---|
| `i2c-4` | 0x50 | EEPROM | `at24`: `/sys/bus/i2c/devices/4-0050/eeprom`, read only |
| `i2c-1` | 0x68 | BMI160 IMU | `bmi160_i2c` |
| `i2c-1` | 0x76 | BME680 environmental sensor | `bme680_i2c`, backported: `in_temp_input`, `in_pressure_input`, `in_humidityrelative_input`, `in_resistance_input` |
| `i2c-2` | 0x44 | OPT3002 light sensor | `opt3001`, backported: `in_intensity_raw`, in nW/cm² |
| `i2c-2` | 0x55 | BQ27426 fuel gauge | `bq27xxx_battery_i2c`, patched: `/sys/class/power_supply/bq27426-0` |
| `i2c-2` | 0x6b | BQ25601 charger | `bq256xx_charger`, backported: `/sys/class/power_supply/bq256xx-charger` |
| `i2c-3` | 0x3e | SX1509 GPIO expander | `pinctrl-sx150x` |
| `i2c-3` | 0x51 | PCF85063 RTC | `rtc-pcf85063`: `rtc1`. The system clock still comes from `rtc0` |

The device tree holds the charger's input limit at the 500 mA the chip comes up with on this board, as
the driver's own default is 2.4 A. Its charge limits stay the chip's defaults, 2.04 A to 4.208 V.

**SFTP.** The SSH server is Dropbear, which runs `/usr/libexec/sftp-server` for every SFTP session.

- `recipes-core/images` adds `openssh-sftp-server`, which Sierra's minimal image leaves out.
- `recipes-support/curl` builds curl and libcurl with `libssh2`, for `sftp://` and `scp://` URLs.

## Using it

Clone it into the top of the Linux source tree, next to `meta-swi`. Sierra's `build.py` adds a
`meta-mangoh` it finds there to the build:

    cd swi-linux-src
    git clone -b release-15 <this repository> meta-mangoh
    make image_bin

Run `make` without leaf's environment loaded, or with `MACH` unset. Leaf exports `MACH=mdm9x06`,
which leaves out the `meta-swi-mdm9x28` layer the WP77xx build needs. Sierra's Makefile picks
`mdm9x28`/`wp` on its own.

## Legato

Legato's WiFi service drives the chip through a platform adaptor script, `legato/pa_wifi.sh`. Legato builds the
script into the service, so it is not part of the image: point the system's sdef at it, beside Legato's WiFi
module.

    #include "$LEGATO_ROOT/modules/WiFi/wifi.sinc"

    buildVars:
    {
        LEGATO_WIFI_PA = <path to meta-mangoh>/legato/pa_wifi.sh
    }

It is mangOH's Cypress script for Legato 21.05 and this layer's kernel. It sets the firmware's country to `XV`, the
worldwide code, each time WiFi starts: the kernel loads the CLM blob, but the NVRAM file leaves the country at
`ALL`. It answers `WIFI_GET_DATA`, which Legato 21.05 asks for.

## DV3 boards

DV3 boards have WL_REG_ON on WP GPIO33 instead of the expander, and need an image of their own. Add
this to `conf/local.conf` in the build directory, and take it out again to build for later boards:

    MANGOH_YELLOW_REV = "dv3"

The bootloader chooses this device tree from the EEPROM, which must start with `mangOH Yellow`.

## Not covered yet

- Keeping Bluetooth pairings across a reboot: BlueZ keeps them in `/var/lib/bluetooth`, and `/var` is
  a tmpfs.
- Classic Bluetooth's RFCOMM, BNEP and HIDP kernel modules.
- The NVRAM file is Broadcom's reference-board file (BCM943430WLSELG), as USI's file for the
  WM-BN-CYW-48 is not public, so its settings are unconfirmed for this module.
- The I2C devices' interrupts, so they are polled, and the magnetometer, which is on no I2C channel.
- The DV3 image has not been tried on a DV3 board.
