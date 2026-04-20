#     Copyright (C) 2022  birdybirdonline & awth13 - see LICENSE.md
#     @ https://github.com/birdybirdonline/Linux-Arctis-7-Plus-ChatMix
    
#     Contact via Github in the first instance
#     https://github.com/birdybirdonline
#     https://github.com/awth13

#!/bin/bash

if [[ "$USER" == root ]]; then
    echo "Please run the install script as non-root user."
    exit 1
fi

CONFIG_DIR="system-config/"
SYSTEMD_CONFIG="arctis7pcm.service"
UDEV_CONFIG="91-steelseries-arctis-7p.rules"
SCRIPT="Arctis_7_Plus_ChatMix.py"

SCRIPT_DIR="$HOME/.local/bin/"
SYSTEMD_DIR="$HOME/.config/systemd/user/"
UDEV_DIR="/etc/udev/rules.d/"

function cleanup {
    echo
    echo "Cleaning up:"
    sudo rm -vf "${UDEV_DIR}${UDEV_CONFIG}"
    rm -f "$UDEV_CONFIG"
    rm -vf "${SCRIPT_DIR}${SCRIPT}"
    rm -vf "${SYSTEMD_DIR}${SYSTEMD_CONFIG}"
    systemctl --user disable "$SYSTEMD_CONFIG"
}

if [[ -v UNINSTALL ]]; then
    echo "Uninstalling Arctis 7+ ChatMix."
    echo "You may need to provide your sudo password for removing udev rule."
    cleanup ; exit 0
fi

echo "Installing Arctis 7+ ChatMix."
echo "Installing script to ${SCRIPT_DIR}${SCRIPT}."
if [[ ! -d "$SCRIPT_DIR" ]]; then
    mkdir -vp $SCRIPT_DIR || \
        { echo "FATAL: Failed to create $SCRIPT_DIR" ; cleanup ; exit 1;}
fi
cp "$SCRIPT" "$SCRIPT_DIR"

echo
echo "Installing udev rule to ${UDEV_DIR}${UDEV_CONFIG}."
echo "You may need to provide your sudo password for this step."
envsubst < "${CONFIG_DIR}${UDEV_CONFIG}" > "$UDEV_CONFIG"
sudo cp "$UDEV_CONFIG" "$UDEV_DIR" || \
    { echo "FATAL: Failed to copy $UDEV_CONFIG" ; cleanup ; exit 1;}
sudo udevadm control --reload-rules
# Re-apply new rules to already-present SteelSeries devices so ACLs and alias take effect
sudo udevadm trigger --verbose --settle --action=add --attr-match=idVendor=1038
rm -f "$UDEV_CONFIG"

echo
echo "Installing systemd unit to ${SYSTEMD_DIR}${SYSTEMD_CONFIG}."
if [[ ! -d "$SYSTEMD_DIR" ]]; then
    mkdir -vp $SYSTEMD_DIR || \
        { echo "FATAL: Failed to create $SCRIPT_DIR" ; cleanup ; exit 1;}
fi
cp "${CONFIG_DIR}${SYSTEMD_CONFIG}" "$SYSTEMD_DIR"

echo
echo "Enabling systemd unit $SYSTEMD_CONFIG."
systemctl --user enable "$SYSTEMD_CONFIG" 2>/dev/null

echo
echo "Post-install checks:"
# Detect connected SteelSeries dongle product IDs and report
if command -v lsusb >/dev/null 2>&1; then
    LSUSB_LINE=$(lsusb -d 1038: 2>/dev/null | head -n1)
    if [[ -n "$LSUSB_LINE" ]]; then
        PROD_ID=$(echo "$LSUSB_LINE" | awk -F: '{print $3}' | awk '{print $1}')
        echo "Detected SteelSeries USB device idProduct=$PROD_ID"
        case "$PROD_ID" in
            220e|227a)
                echo "Known dongle ID found; udev rules include this mapping."
                ;;
            *)
                echo "WARNING: Unknown SteelSeries product ID ($PROD_ID). You may need to add it to system-config/91-steelseries-arctis-7p.rules."
                ;;
        esac
    else
        echo "No SteelSeries USB device detected right now; udev rules installed and will apply on next plug." 
    fi
fi

# Hint if the user systemd instance is not lingering (device-triggered user units won't start automatically)
if command -v loginctl >/dev/null 2>&1; then
    if loginctl show-user "$USER" 2>/dev/null | grep -q '^Linger=no'; then
        echo "NOTE: Your user systemd is not lingering. To allow device-triggered user services, run:"
        echo "  sudo loginctl enable-linger $USER"
    fi
fi
