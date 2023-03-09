#!/usr/bin/env bash
# Credit for original concept and initial work to: Jesse Jarzynka

# Updated by: rallyemax (2022-01-14)
#   * replaced 2FA section with generic openconnect prompt response mechanism
#   * create settings.conf.example and add settings.conf to .gitignored
#   * so configuration changes aren't tracked by git
#   * override configuration variables from settings.conf so that the project can be
#     updated via fetch and pull without creating conflicts on configuration values.

# Updated by: Ventz Petkov (8-31-18)
#   * merged feature for token/pin input (ex: Duo/Yubikey/Google Authenticator) contributed by Harry Hoffman <hhoffman@ip-solutions.net>
#   * added option to pick "push/sms/phone" (ex: Duo) vs token/pin (Yubikey/Google Authenticator/Duo)

# Updated by: Ventz Petkov (11-15-17)
#   * cleared up documentation
#   * incremented 'VPN_INTERFACE' to 'utun99' to avoid collisions with other VPNs

# Updated by: Ventz Petkov (9-28-17)
#   * fixed for Mac OS X High Sierra (10.13)

# Updated by: Ventz Petkov (7-24-17)
#   * fixed openconnect (did not work with new 2nd password prompt)
#   * added ability to work with "Duo" 2-factor auth
#   * changed icons

# <xbar.title>VPN Status</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>Ventz Petkov</xbar.author>
# <xbar.author.github>ventz</xbar.author.github>
# <xbar.desc>Connect/Disconnect OpenConnect + show status</xbar.desc>
# <xbar.image></xbar.image>

# Default settings (overriden by settings.conf)
VPN_EXECUTABLE=/usr/local/bin/openconnect
VPN_HOST="vpn.example.invalid"
VPN_USERNAME="anonymous"
VPN_DISPLAYNAME="VPN"
PROMPT_RESPONSES=""
VPN_INTERFACE="utun99"
LOGFILE="$HOME/Library/Logs/xbar-openconnect.log"

# Set absolute path to script (pedantic but works)
PLUGINS_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPT_PATH="$PLUGINS_DIR/$0"

# Default output to /tmp, but can be overriden with param2=log
OUTPUT="/tmp/xbar-openconnect.log"

# Override the settings defaults
CONFIG_FILE="$PLUGINS_DIR/openconnect-gui-menu-bar/settings.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Retrieve that password securely at run time when connecting
# and feed it to openconnect. No storing passwords in the clear!
GET_VPN_PASSWORD="security find-generic-password -wl $VPN_HOST"

# Command to determine if VPN is connected or disconnected
VPN_CONNECTED="/sbin/ifconfig | grep -A3 $VPN_INTERFACE | grep inet"
TUN_EXISTS="/sbin/ifconfig | grep -q $VPN_INTERFACE"

# Command to run to disconnect VPN
VPN_DISCONNECT_CMD="sudo killall -2 openconnect"

case "$1" in
    connect)
        # If tunnel exists, first dismantle it
        if eval "$TUN_EXISTS"; then
            eval "$VPN_DISCONNECT_CMD"
            while eval "$TUN_EXISTS"; do sleep 1; done
        fi

        # We expect param2 to be either "split" or "full", which chooses EXTRA_ARGS_SPLIT or
        # EXTRA_ARGS_FULL, respectively, from the config file to be the array pointed to by
        # EXTRA_ARGUMENTS. In reality we default to split and make full a special case.
        if [ -n "$2" ] && [ "$2" = "full" ]; then
            EXTRA_ARGUMENTS=("${EXTRA_ARGS_FULL[@]}")
        else
            EXTRA_ARGUMENTS=("${EXTRA_ARGS_SPLIT[@]}")
        fi

        if [ -n "$3" ] && [ "$3" = "log" ]; then
            EXTRA_ARGUMENTS+=('--verbose')
            OUTPUT="$LOGFILE"
            echo -e "################ "$(date +"%Y-%m-%d %H:%M:%S")" ### CONFIG ################\n" >> "$OUTPUT"
            cat "$CONFIG_FILE" >> "$OUTPUT"
            echo -e "\n######################################## ENV    ################\n" >> "$OUTPUT"
            ( set -o posix ; set ) >> "$OUTPUT"
            echo -e "\n######################################## OUTPUT ################\n" >> "$OUTPUT"
        fi

        VPN_PASSWORD=$(eval "$GET_VPN_PASSWORD")
        # Connect based on your 2FA selection (see: $PUSH_OR_PIN for options)
        # For anything else (non-duo) - you would provide your token (see: stoken)
        echo -e "${PROMPT_RESPONSES}${VPN_PASSWORD}\n" | sudo "$VPN_EXECUTABLE" "$VPN_HOST" -u "$VPN_USERNAME" -i "$VPN_INTERFACE" "${EXTRA_ARGUMENTS[@]:+${EXTRA_ARGUMENTS[@]}}" >> "$OUTPUT" 2>&1 &

        # Wait for connection so menu item refreshes instantly
        until eval "$VPN_CONNECTED"; do sleep 1; done
        ;;
    disconnect)
        eval "$VPN_DISCONNECT_CMD"
        # Wait for disconnection so menu item refreshes instantly
        while eval "$VPN_CONNECTED"; do sleep 1; done
        ;;
esac

if [ -n "$(eval "$VPN_CONNECTED")" ]; then
    echo "$VPN_DISPLAYNAME 🔒"
    echo '---'
    echo "Disconnect VPN | shell='$SCRIPT_PATH' param1=disconnect terminal=false refresh=true"
    exit
else
    echo "$VPN_DISPLAYNAME ❌"
    # Alternative icon -> but too similar to "connected"
    #echo "VPN 🔓"
    echo '---'
    echo "Connect VPN (split) | shell='$SCRIPT_PATH' param1=connect param2=split terminal=false refresh=true"
    echo "Connect VPN (split, logging) | shell='$SCRIPT_PATH' param1=connect param2=split param3=log terminal=false refresh=true"
    echo "Connect VPN (full) | shell='$SCRIPT_PATH' param1=connect param2=full terminal=false refresh=true"
    # For debugging!
    #echo "Connect VPN | shell='$SCRIPT_PATH' param1=connect terminal=true refresh=true"
    exit
fi
