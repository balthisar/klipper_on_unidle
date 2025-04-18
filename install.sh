#!/bin/bash
# This file based on Julian Schill's install script for klipper-led_effect
# Force script to exit if an error occurs
set -e

KLIPPER_PATH="${HOME}/klipper"
KLIPPER_SERVICE_NAME=klipper
SYSTEMDDIR="/etc/systemd/system"
MOONRAKER_CONFIG_DIR="${HOME}/printer_data/config"
DO_PATCH="y"

# Fall back to old directory for configuration as default
if [ ! -d "${MOONRAKER_CONFIG_DIR}" ]; then
    echo "\"$MOONRAKER_CONFIG_DIR\" does not exist. Falling back to "${HOME}/klipper_config" as default."
    MOONRAKER_CONFIG_DIR="${HOME}/klipper_config"
fi

usage(){ echo "Usage: $0 [-k <klipper path>] [-s <klipper service name>] [-c <configuration path>] [-u]" 1>&2; exit 1; }
# Parse command line arguments
while getopts "k:s:c:uh" arg; do
    case $arg in
        k) KLIPPER_PATH=$OPTARG;;
        s) KLIPPER_SERVICE_NAME=$OPTARG;;
        c) MOONRAKER_CONFIG_DIR=$OPTARG;;
        u) UNINSTALL=1;;
        h) usage;;
    esac
done

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "$0" )" && pwd )"

# Verify Klipper has been installed
check_klipper()
{
    if [ "$(sudo systemctl list-units --full -all -t service --no-legend | grep -F "$KLIPPER_SERVICE_NAME.service")" ]; then
        echo "Klipper service found with name "$KLIPPER_SERVICE_NAME"."
    else
        echo "[ERROR] Klipper service with name "$KLIPPER_SERVICE_NAME" not found, please install Klipper first or specify name with -s."
        exit -1
    fi
}

check_folders()
{
    if [ ! -d "$KLIPPER_PATH/klippy/extras/" ]; then
        echo "[ERROR] Klipper installation not found in directory \"$KLIPPER_PATH\". Exiting"
        exit -1
    fi
    echo "Klipper installation found at $KLIPPER_PATH"

    if [ ! -f "${MOONRAKER_CONFIG_DIR}/moonraker.conf" ]; then
        echo "[ERROR] Moonraker configuration not found in directory \"$MOONRAKER_CONFIG_DIR\". Exiting"
        exit -1
    fi
    echo "Moonraker configuration found at $MOONRAKER_CONFIG_DIR"
}

# Link extension to Klipper
link_extension()
{
    echo -n "Linking extension to Klipper... "
    ln -sf "${SRCDIR}/on_unidle.py" "${KLIPPER_PATH}/klippy/extras/on_unidle.py"
    echo "[OK]"
}

# Restart moonraker
restart_moonraker()
{
    echo -n "Restarting Moonraker... "
    sudo systemctl restart moonraker
    echo "[OK]"
}

# Add updater for on_idle to moonraker.conf
add_updater()
{
    echo -e -n "Adding update manager to moonraker.conf... "

    update_section=$(grep -c '\[update_manager on_unidle\]' ${MOONRAKER_CONFIG_DIR}/moonraker.conf || true)
    if [ "${update_section}" -eq 0 ]; then
        echo -e "\n" >> ${MOONRAKER_CONFIG_DIR}/moonraker.conf
        while read -r line; do
            echo -e "${line}" >> ${MOONRAKER_CONFIG_DIR}/moonraker.conf
        done < "$PWD/moonraker_update.txt"
        echo -e "\n" >> ${MOONRAKER_CONFIG_DIR}/moonraker.conf
        echo "[OK]"
        restart_moonraker
        else
        echo -e "[update_manager on_unidle] already exists in moonraker.conf [SKIPPED]"
    fi
}

restart_klipper()
{
    echo -n "Restarting Klipper... "
    sudo systemctl restart $KLIPPER_SERVICE_NAME
    echo "[OK]"
}

start_klipper()
{
    echo -n "Starting Klipper... "
    sudo systemctl start $KLIPPER_SERVICE_NAME
    echo "[OK]"
}

stop_klipper()
{
    echo -n "Stopping Klipper... "
    sudo systemctl stop $KLIPPER_SERVICE_NAME
    echo "[OK]"
}

uninstall()
{
    if [ -f "${KLIPPER_PATH}/klippy/extras/on_unidle.py" ]; then
        echo -n "Uninstalling... "
        rm -f "${KLIPPER_PATH}/klippy/extras/on_unidle.py"
        echo "[OK]"
        echo "You can now remove the [update_manager on_unidle] section in your moonraker.conf and delete this directory. Also remove all on_unidle configurations from your Klipper configuration."
        echo "If ${KLIPPER_PATH}/klippy/extras/display/menu.py was patched, you can remove the changes manually, although it's not necessary to do so."
    else
        echo "on_unidle.py not found in \"${KLIPPER_PATH}/klippy/extras/\". Is it installed?"
        echo "[FAILED]"
    fi
}

ask_yes_no()
{
  while true; do
    read -p "$1 ([y]es/[a]bort/[s]kip): " response
    case $response in
      [yY])
        echo "y"
        return 0
        ;;
      [aA])
        echo "a"
        return 0
        ;;
      [sS])
        echo "s"
        return 0
        ;;
      *)
        echo "Invalid input. Please enter y, a, or s."
        ;;
    esac
  done
}

get_user_acknowledgment()
{
    echo "This script may have to modify ${KLIPPER_PATH}/klippy/extras/display/menu.py"
    echo "in order for this Klippy Extra to work. You can examine the menu.py.patch"
    echo "file in this repository to see the changes that will be made. You may"
    echo "have to re-install this patch after Klipper updates. These required"
    echo "changes are also PR#6897 and can be viewed on Klipper's github repo."
    echo "You do not have to apply this patch if you don't want to use the rotary"
    echo "encoder to take the printer out of Idle state."
    echo "Choose y to patch, a to abort, or s to skip patch but install everything else."
    DO_PATCH=$(ask_yes_no "How to proceed?")
    if [[ $DO_PATCH == "a" ]]; then
      exit
    fi    
}

patch_menu()
{
    if [[ $DO_PATCH == "y" ]]; then
        set +e
        patch "${KLIPPER_PATH}/klippy/extras/display/menu.py" "${SRCDIR}/menu.py.patch" --dry-run --forward
        result=$?
        set -e
          
        if [ $result -eq 0 ]; then
            echo "Patch doesn't appear to be installed. Patching file."
            patch "${KLIPPER_PATH}/klippy/extras/display/menu.py" "${SRCDIR}/menu.py.patch"
        else
            echo "It appears the patch is already applied. Skipping."
        fi
    else
        echo "User chose to skip installing the patch."
    fi
}

# Helper functions
verify_ready()
{
    if [ "$EUID" -eq 0 ]; then
        echo "[ERROR] This script must not run as root. Exiting."
        exit -1
    fi
}

# Run steps
verify_ready
check_klipper
check_folders
if [ ! $UNINSTALL ]; then
    get_user_acknowledgment
fi
stop_klipper
if [ ! $UNINSTALL ]; then
    link_extension
    add_updater
    patch_menu
else
    uninstall
fi
start_klipper
