#!/bin/sh
# The Bluetooth half of WiFi and Bluetooth sharing the antenna: turns on the CYW20719's SECI link to the
# CYW43364. cywifi.sh runs this when WiFi starts, and ttyUSB.sh when the controller is attached. The WiFi
# half is two settings in the NVRAM file: btcxwarflags=0x1 and btc_mode=5.
#
# The chip's firmware already has coexistence, and its Coexistence Config is type 2. At every HCI Reset it
# starts the SECI engine if the top bit of the ECSI config word is set, which it isn't as shipped. So this
# selects the two pins, sets the rate and that bit in the chip's RAM, and resets it. A reboot clears them;
# nothing goes to the chip's flash.
#
# Only on a board with R301 and R303 removed: they ground WL_GPIO_1 and WL_GPIO_2, and P16 must not drive
# a grounded line. The image has this script only when built with MANGOH_YELLOW_SECI = "y", which says they
# are removed, so nothing checks for them.
#
# See also: https://github.com/seemoo-lab/internalblue
# See also: https://github.com/seemoo-lab/frankenstein

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

HCI=hci0
WLAN=wlan0

SECI_IN_PIN=17      # WL_GPIO_1
SECI_OUT_PIN=16     # WL_GPIO_2
SECI_BAUD=3000000

# This chip's ROM is 20739B1, LMP subversion 0x420e. The RAM addresses hold for this ROM only.
LMP_SUBVERSION=0x420e

# Vendor HCI commands
HCI_WRITE_RAM=0x004c
HCI_READ_RAM=0x004d

# Registers. Their names come from the symbol table of the sister chip CYW20735B1.
iocfg_p() { echo $((0x338200 + 4 * $1)) ; }         # a pin's configuration: 0 is input on
iocfg_fcn_p() { echo $((0x338400 + 4 * $1)) ; }     # a pin's output function
IOCFG_PREMUX_14=$((0x338354))                       # byte 2 selects SECI input: its pin + 1
IOCFG_FCN_SECI_OUT="0x5C 0x08 0x00 0x00"

# Variables in this ROM's RAM, found by disassembling it
COEX_CONFIG=$((0x202709))                           # Coexistence Config; byte 0 is its type
COEX_CONFIG_TYPE="02"
ECSI_CONFIG_WORD=$((COEX_CONFIG + 28))              # the top bit enables the engine
ECSI_ENABLED=$((0x2831F3))                          # 01 while the engine runs; ecsiEnabled on the sister chip
SECI_BAUD_RATE=$((0x2037E8))                        # what the engine reads the rate from

REPLY_FILE=/tmp/cyw20719-enable-seci.$$
LEAVE_DOWN=

log() { echo "cyw20719-enable-seci: $*" > /dev/kmsg ; echo "$*" ; }

cleanup() {
    rm -f "$REPLY_FILE"
    [ -z "$LEAVE_DOWN" ] || hciconfig $HCI down
}

le32() { printf '0x%02x 0x%02x 0x%02x 0x%02x' $(($1 & 255)) $((($1 >> 8) & 255)) $((($1 >> 16) & 255)) $((($1 >> 24) & 255)) ; }


#### The chip's RAM, over HCI ####

# hci_vendor_cmd OPCODE BYTE...: prints the reply's bytes. Given up on after 3 s, as hcitool waits forever
# on a dead controller.
hci_vendor_cmd() {
    hcitool -i $HCI cmd 0x3f "$@" > "$REPLY_FILE" 2>&1 &
    vendor_pid=$!
    vendor_wait=0
    while kill -0 $vendor_pid 2>/dev/null ; do
        if [ $vendor_wait -ge 60 ] ; then
            kill -9 $vendor_pid 2>/dev/null
            return 1
        fi
        sleep 0.05
        vendor_wait=$((vendor_wait + 1))
    done
    sed -n '/HCI Event/,$p' "$REPLY_FILE" | tail -n +2 | tr -d '\n' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//'
    echo
}

# ram_read ADDRESS LENGTH: the bytes there. hcitool prints the first event it reads, which may be another's,
# so keep asking for the real reply.
ram_read() {
    read_try=0
    while [ $read_try -lt 40 ] ; do
        read_reply=$(hci_vendor_cmd $HCI_READ_RAM $(le32 "$1") $(printf '0x%02x' "$2")) || return 1
        case "$read_reply" in
            "01 4D FC 00 "*) echo "${read_reply#01 4D FC 00 }" ; return 0 ;;
        esac
        read_try=$((read_try + 1))
    done
    return 1
}

# ram_write ADDRESS BYTE...
ram_write() {
    write_address=$1
    shift
    hci_vendor_cmd $HCI_WRITE_RAM $(le32 "$write_address") "$@" > /dev/null
}


#### Coexistence on the chip ####

chip_is_as_expected() {
    hciconfig $HCI version | grep -q "Subversion: $LMP_SUBVERSION" || return 1
    [ "$(ram_read $COEX_CONFIG 1)" = "$COEX_CONFIG_TYPE" ]
}

wiced_bt_coex_is_enabled() {
    [ "$(ram_read $ECSI_ENABLED 1)" = "01" ]
}

# As wiced_hal_gpio_select_function(pin, WICED_GCI_SECI_IN), through the registers
select_seci_in_pin() {
    ram_write "$(iocfg_p "$1")" 0x00 0x00 0x00 0x00
    set -- "$1" $(ram_read $IOCFG_PREMUX_14 4)
    ram_write $IOCFG_PREMUX_14 "0x$2" "0x$3" "$(printf '0x%02x' $(($1 + 1)))" "0x$5"
}

# As wiced_hal_gpio_select_function(pin, WICED_GCI_SECI_OUT), through the registers
select_seci_out_pin() {
    ram_write "$(iocfg_p "$1")" 0x00 0x00 0x00 0x00
    ram_write "$(iocfg_fcn_p "$1")" $IOCFG_FCN_SECI_OUT
}

set_ecsi_enable_bit() {
    set -- $(ram_read $ECSI_CONFIG_WORD 4)
    [ $# -ge 4 ] || return 1
    ram_write $ECSI_CONFIG_WORD "0x$1" "0x$2" "0x$3" "$(printf '0x%02x' $((0x$4 | 0x80)))"
}

# wiced_bt_coex_enable IN_PIN OUT_PIN BAUD: does from the host what a WICED application does on the chip
wiced_bt_coex_enable() {
    select_seci_in_pin "$1"
    select_seci_out_pin "$2"
    ram_write $SECI_BAUD_RATE $(le32 "$3")
    set_ecsi_enable_bit || return 1
    controller_reset
    wiced_bt_coex_is_enabled
}


#### The board ####

wait_for_path() {
    wait_seconds=0
    until [ -e "$1" ] ; do
        [ $wait_seconds -lt "$2" ] || return 1
        sleep 1
        wait_seconds=$((wait_seconds + 1))
    done
}

wifi_is_up() {
    [ -e /sys/class/net/$WLAN/flags ] && [ $(($(cat /sys/class/net/$WLAN/flags) & 1)) -eq 1 ]
}

# The controller starts powered off. Bring it up to reach its RAM; cleanup puts it back.
controller_up() {
    hciconfig $HCI | grep -q 'UP RUNNING' && return 0
    hciconfig $HCI up || return 1
    LEAVE_DOWN=1
}

# Down and up, which sends HCI Reset
controller_reset() {
    hciconfig $HCI down
    sleep 1
    hciconfig $HCI up
    sleep 1
}


#### Start ####

trap cleanup EXIT

# Not until WiFi is up: there is nothing to share before then. It also keeps P16, which idles high, off
# WL_GPIO_2 while the WiFi chip powers up, as that is one of its boot straps. cywifi.sh runs this again when
# WiFi starts.
wifi_is_up || { log "WiFi not up yet: left for when it starts" ; exit 0 ; }
wait_for_path /sys/class/bluetooth/$HCI 30 || { log "no $HCI: left off" ; exit 1 ; }

controller_up || { log "$HCI will not come up: left off" ; exit 1 ; }
chip_is_as_expected || { log "not the ROM and config expected: left off" ; exit 1 ; }

if wiced_bt_coex_is_enabled ; then
    log "already on"
    exit 0
fi

if ! wiced_bt_coex_enable $SECI_IN_PIN $SECI_OUT_PIN $SECI_BAUD ; then
    log "enable did not take: ECSI config word $(ram_read $ECSI_CONFIG_WORD 4), running $(ram_read $ECSI_ENABLED 1)"
    exit 1
fi
log "on: input P$SECI_IN_PIN, output P$SECI_OUT_PIN, $SECI_BAUD baud"
