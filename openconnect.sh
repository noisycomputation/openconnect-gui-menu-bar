#!/bin/bash
# Credit for original concept and initial work to: Jesse Jarzynka

# Updated by: rallyemax (2022-01-14)
#   * replaced 2FA section with generic openconnect prompt response mechanism
#   * create .gitignored and add config.gitignored so configuration changes aren't tracked by git
#   * override configuration variables from config.gitignored so that the project can be
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

# <bitbar.title>VPN Status</bitbar.title>
# <bitbar.version>v1.1</bitbar.version>
# <bitbar.author>Ventz Petkov</bitbar.author>
# <bitbar.author.github>ventz</bitbar.author.github>
# <bitbar.desc>Connect/Disconnect OpenConnect + show status</bitbar.desc>
# <bitbar.image></bitbar.image>

#########################################################
# INSTRUCTIONS #
#########################################################

# 1.) Create file `/etc/sudoers.d/openconnect` with the following lines, replacing
#     `macos-username` with your Mac username. Choose only ONE of the two `openconnect`
#     binaries in the first line: the first one is for Intel Macs, the second for Apple Silicon.
#macos-username ALL=(ALL) NOPASSWD: /usr/local/bin/openconnect OR /opt/homebrew/openconnect
#macos-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect

# 2.) Create an encrypted password entry in your OS X Keychain:
#      a.) Open "Keychain Access" and 
#      b.) Click on "login" keychain (top left corner)
#      c.) Click on "Passwords" category (bottom left corner)
#      d.) From the "File" menu, select -> "New Password Item..."
#      e.) For "Keychain Item Name" and "Account Name" use the value for
#          "VPN_HOST" and "VPN_USERNAME" respectively
#      f.) For "Password" enter your VPN AnyConnect password.

# 3.) Openconnect query responses
#       This is rather crude, but any queries made by openconnect (which would normally
#       require user input) are handled by piping in a newline-terminated string that
#       responds to these queries. Examples:
#         - an organization uses a self-signed certificate, so the user is required to
#           either accept it with "yes" or reject it before being prompted for the
#           password. No 2FA or tokens are required by the VPN server. In this case,
#           the value might only be "yes".
#         - if the organization uses 2FA, this value might be "push" (e.g. Duo) or
#           "pin" (Yubikey, Google Authenticator, TOTP)
#       Whatever prompt responses are required to be entered when using openconnect
#       manually should be defined in the variable PROMPT_RESPONSES below, with each
#       response followed by \n:
#         - PROMPT_RESPONSES="yes\n"
#         - PROMPT_RESPONSES="yes\npush\n"

# 4.) Override the following configuration variables, as needed, in file `config.gitignored`.
#     This file is listed in `.gitignored` (thus the extension), which means it will not be
#     tracked by `git`. This allows the script to be updated using `git fetch && git pull`
#     without creating conflicts, and if you publicly fork the project, keeps your personal
#     information (like URL and username) off the public git repo.
VPN_EXECUTABLE=/usr/local/bin/openconnect
VPN_HOST="none.example.invalid"
VPN_USERNAME="anonymous"
PROMPT_RESPONSES=""
VPN_INTERFACE="utun99"
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# END OF INSTRUCTIONS #
#########################################################

# Override the variables above
[ -f './config.gitignored' ] && source ./config.gitignored

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
        echo -e "${PROMPT_RESPONSES}${VPN_PASSWORD}\n" | sudo "$VPN_EXECUTABLE" -u "$VPN_USERNAME" -i "$VPN_INTERFACE" "$VPN_HOST" &> /dev/null &

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
    echo "VPN 🔒"
    echo '---'
    echo "Disconnect VPN | bash='$0' param1=disconnect terminal=false refresh=true"
    exit
else
    echo "VPN ❌"
    # Alternative icon -> but too similar to "connected"
    #echo "VPN 🔓"
    echo '---'
    echo "Connect VPN | bash='$0' param1=connect terminal=false refresh=true"
    # For debugging!
    #echo "Connect VPN | bash='$0' param1=connect terminal=true refresh=true"
    exit
fi
