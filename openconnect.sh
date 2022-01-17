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
EXTRA_ARGUMENTS=""
VPN_INTERFACE="utun99"

# Set absolute path to script (pedantic but works)
PLUGINS_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPT_PATH="$PLUGINS_DIR/$0"

# Override the settings defaults
CONFIG_FILE="$PLUGINS_DIR/openconnect-gui-menu-bar/settings.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Retrieve that password securely at run time when connecting
# and feed it to openconnect. No storing passwords in the clear!
GET_VPN_PASSWORD="security find-generic-password -wl $VPN_HOST"

# Command to determine if VPN is connected or disconnected
VPN_CONNECTED="/sbin/ifconfig | grep -A3 $VPN_INTERFACE | grep inet"

# Command to run to disconnect VPN
VPN_DISCONNECT_CMD="sudo killall -2 openconnect"

case "$1" in
    connect)
        VPN_PASSWORD=$(eval "$GET_VPN_PASSWORD")
        # Connect based on your 2FA selection (see: $PUSH_OR_PIN for options)
        # For anything else (non-duo) - you would provide your token (see: stoken)
        echo -e "${PROMPT_RESPONSES}${VPN_PASSWORD}\n" | sudo "$VPN_EXECUTABLE" "$VPN_HOST" -u "$VPN_USERNAME" -i "$VPN_INTERFACE" "${EXTRA_ARGUMENTS[@]:+"${EXTRA_ARGUMENTS[@]}"}"

        # Wait for connection so menu item refreshes instantly
        until eval "$VPN_CONNECTED"; do sleep 1; done
        ;;
    disconnect)
        eval "$VPN_DISCONNECT_CMD"
        # Wait for disconnection so menu item refreshes instantly
        until [ -z "$(eval "$VPN_CONNECTED")" ]; do sleep 1; done
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
    echo "Connect VPN | shell='$SCRIPT_PATH' param1=connect terminal=false refresh=true"
    # For debugging!
    #echo "Connect VPN | shell='$SCRIPT_PATH' param1=connect terminal=true refresh=true"
    exit
fi
