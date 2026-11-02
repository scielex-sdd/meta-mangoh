# meta-mangoh

A Yocto layer for the mangOH Yellow with a Sierra Wireless WP77xx (WP7702) module, for Sierra's
Release 15 Linux (SWI9X06Y_03.00.x: Yocto 3.1 "dunfell", kernel 4.14). The `release-15` branch is
a port of the original layer, which was written for Release 13 (Yocto 2.5, kernel 3.18).

## What it does

**Cypress CYW43430 WiFi.** The chip sits on the WP's SDIO port (`sdhc_2`).

- `recipes-kernel/linux-msm`: a device-tree patch to Sierra's `swi-wp-mangoh-yellow.dtsi` that
  describes WL_REG_ON (GPIO 1 of the SX1509 expander) as the SDIO slot's supply. The kernel
  powers the chip before it scans the bus and owns the line from then on, so nothing in
  userspace toggles it and it isn't pulled away underneath the driver at shutdown. A config
  fragment builds the in-kernel `brcmfmac` driver as a module, loaded at boot.
- `recipes-connectivity/brcmfmac43430-support`: the chip's firmware, its NVRAM file and CLM blob
  in `/lib/firmware/brcm/`, and `/etc/init.d/cywifi`, which Legato's WiFi service calls (through
  mangOH's `pa_wifi.sh`) to bring `wlan0` up and down.
- `recipes-core/images`: adds the firmware, the driver, `wpa-supplicant` and `iw` to the image.

## Using it

Clone it into the top of the Linux source tree, next to `meta-swi`. Sierra's `build.py` adds a
`meta-mangoh` it finds there to the build:

    cd swi-linux-src
    git clone -b release-15 <this repository> meta-mangoh
    make image_bin

Run `make` without leaf's environment loaded, or with `MACH` unset. Leaf exports `MACH=mdm9x06`,
which leaves out the `meta-swi-mdm9x28` layer the WP77xx build needs. Sierra's Makefile picks
`mdm9x28`/`wp` on its own.

## Changes from the Release 13 layer

Removed, because Release 15 does not need them or they no longer apply:

- **backports 4.14-rc2:** it only existed to get a newer brcmfmac and cfg80211 onto kernel 3.18.
  Kernel 4.14 has them.
- **The 3.18 kernel patches and config fragments:** loadable `sdhci-msm`, no cfg80211 autoload,
  Bluetooth crypto backports, WM8944 digital mic, CAN, framebuffer.
- **BlueZ 5.52 and ell 0.26:** dunfell has its own.
- **Copies of `passwd`, `group`, `shadow`, `gshadow` and `mdev.conf`:** they replaced Sierra's
  newer files of the same name.
- **The Bluetooth start-up scripts and the unused `/etc/network/interfaces`.**

## Not covered yet

- Bluetooth (the Cypress chip's BT half, attached with `btattach` on its USB-UART).
- The sensors on the I2C switch (BMI160, BQ25601, BQ27426, OPT3002, PCF85063, the EEPROM). They
  still need nodes in the device tree.
- mangOH Yellow DV3 boards, which use WP GPIO33 for WL_REG_ON instead of the expander.
- The NVRAM file is Broadcom's reference-board file (BCM943430WLSELG), marked as placeholders,
  with a fixed MAC address (00:90:4c:c5:12:38). Check that units on the same network get distinct
  MAC addresses, and that the radio settings suit the board.
