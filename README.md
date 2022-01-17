### OpenConnect - macOS GUI Menu Bar for connecting/disconnecting via OpenConnect

# What is this?

An easy way to get OpenConnect VPN to have an macOS menu bar GUI for:
* connecting
* disconnecting
* status changes (icon)

Full(-ish) support for multi-factor authentication (especially Duo)!

![OpenConnect Connected](https://github.com/noisycomputation/openconnect-gui-menu-bar/blob/master/images/vpn-connected.png)

![OpenConnect Disconnected](https://github.com/noisycomputation/openconnect-gui-menu-bar/blob/master/images/vpn-disconnected.png)

# How to run it:

## 1. Install openconnect

If you have Homebrew, you can run `brew install openconnect`. Note that openconnect has
supported the built-in utun device since 2014 and no longer requires installation
of tun/tap drivers.

## 2. Update your sudoers file to allow running/killing openconnect without a password

Create the file `/etc/sudoers.d/openconnect-gui-menu-bar` by running
```
    sudo visudo -f /etc/sudoers.d/openconnect-gui-menu-bar
```
Note that using visudo this is the only safe way to edit your sudoers file, because
it will not let you save the file if it contains errors. If you use another method
and inadvertently make a mistake, you will be unable to use sudo, which will make
it tricky to fix the sudoers file.

Add the following lines in the editor that opens, replacing `macos-username` with
your Mac username. Choose only ONE of the two `openconnect` binaries in the first
line: the first one is for Intel Macs, the second for Apple Silicon:
```
    macos-username ALL=(ALL) NOPASSWD: /usr/local/bin/openconnect OR /opt/homebrew/openconnect
    macos-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect
```

> Note: if the editor looks strange and you don't know how to operate it,
> it is likely [vim](https://github.com/vim/vim). A learning opportunity has presented itself,
> take advantage of it.

## 3. Install xbar
https://github.com/matryer/xbar

xbar provides an easy way to put "things" (for output and input) in your macOS menu bar.

## 4. Install this plugin into xbar's plugins directory

Clone this repository into xbar's plugins directory and create a symlink
in this directory pointing to the bash script `openconnect.sh` in this repo's root:
```
    cd "~/Library/Application Support/xbar/plugins"
    git clone https://github.com/noisycomputation/openconnect-gui-menu-bar.git
    ln -s openconnect-gui-menu-bar/openconnect.sh
```
## 5. Configure the plugin

Copy the file `settings.conf.example` to `settings.conf` in the repo's root and
edit `settings.conf` to configure the plugin.

Note that the repo's `.gitignore` file includes an entry for `settings.conf`,
which means that git will ignore this file. This makes it possible to update
the plugin with `git fetch && git pull` without creating a merge conflict. It
also avoids sharing your configuration details with the world if you fork this
repository on a public repo provider like Github.

The `PROMPT_RESPONSES` variable is a rather crude hack that allows the openconnect
script to be run non-interactively. Basically, any queries made by openconnect
*other* than the VPN password query are handled by piping in a string that
contains a response plus a newline (`\n`) for each query.

To find out what values you need, first connect to your VPN manually by
running `sudo openconnect -u {your VPN username} {VPN address}` and noting
down all the answers to the questions openconnect asks you, other than
your VPN password. The `PROMPT_RESPONSES` string should be a concatenation
of all these answers, each followed by `\n`. If the answers are "yes",
"no", and "push", the string should be "yes\nno\npush\n".

For example, if a VPN server uses a self-signed certificate, the user is
required to either accept it with "yes" or reject it before being prompted for the
password. If this is the only pre-password query, the string would be `"yes\n"`.

If the server uses 2FA, this value might be "push" (e.g. Duo) or "pin" (Yubikey,
Google Authenticator, TOTP).

## 6. Create your KeyChain password (to store your VPN password securely)

  - Open "Keychain Access".
  - Click on "login" keychain (top left corner).
  - Click on "Passwords" tab.
  - From the "File" menu, select -> "New Password Item..."
  - For "Keychain Item Name" and "Account Name" use the
    "VPN_HOST" and "VPN_USERNAME" values from `settings.conf`.
  - For "Password" enter your VPN password.

That's it! Now you can use the GUI to connect and disconnect!
(and if you are using Duo - get the 2nd factor push to your phone)

## 7. Run xbar

Use your favorite way to run the xbar app (Finder, Spotlight, Launchpad). If it
is already running, click on it and click on "Refresh all" to reload the plugin
and re-process its configuration.

You should see an icon in the menu bar!

## 8. (Optional) Split Tunneling

You can configure split tunnels (where only some traffic is sent via the VPN tunnel, as
opposed to all or most of it) by using [vpn-slice](https://github.com/dlenski/vpn-slice). You
can install vpn-slice via Homebrew with `brew install vpn-slice`.

To use it, you must tell the openconnect binary to run the script by adding the argument
`--script=` followed by the path to the vpn-slice binary (run `which vpn-slice` to get the
path on your system), followed by arguments to the vpn-slice script where you define
routes you would like to use. The entire string should be appended to the EXTRA_ARGUMENTS
variable in `settings.conf`. Note that this variable is a bash array!

The following example is valid on an Apple Silicon system:
```
    EXTRA_ARGUMENTS=( "--script=/opt/homebrew/bin/vpn-slice --no-ns-hosts --domains-vpn-dns=mycompany.com 10.0.34.0/24 10.0.35.0/24" )
```
Here is what the arguments mean:
  - `no-ns-hosts`: do not add the VPN-server-provided DNS server(s) to `/etc/hosts` under aliases like `utun99.dns0`.
  - `domains-vpn-dns`: use the VPN-server-provided DNS server(s) *only* to perform lookups on the `mycompany.com` domain (or whatever you specify), and use the system defined DNS configuration for all other queries.
  - `10.0.34.0/24` etc.: specify subnets you want to route over the VPN.

The configuration above, then, will route via the VPN traffic to all addresses on the 10.0.34.0/24 and 10.0.35.0/24 subnets; will use the VPN-provided DNS server(s) to lookup hosts on the `mycompany.com` domain; and will not add any aliases pointing to the VPN-provided DNS server(s) to my `/etc/hosts` file.

See the `vpn-slice` documentation for more information.


# Problems Connecting?

If you have another VPN (ex: OpenVPN), you might already have an
'utun0' interface. Please check with '/sbin/ifconfig'. If that's the
case, in step #2 above you need to add:

```
VPN_INTERFACE="utun1"
```

If you already have an utun0 and an utun1, then you need to
change it to the next available, ex: utun2.

In order to make sure this doesn't happen - I've chosen 'utun99'

# Help/Questions/Comments:
For help or more info, feel free to contact me or open an issue here!

> This helpful offer was in the upstream repo, but frankly I'm highly unlikely
> to respond.
