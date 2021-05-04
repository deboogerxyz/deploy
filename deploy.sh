#!/bin/sh

# Programs to install
pkgs="curl base-devel git dash neovim scrot xclip zsh-autosuggestions pulseaudio xorg xorg-xinit unclutter mpv sxiv zathura-pdf-mupdf ttf-joypixels"
aurpkgs="dashbinsh lf picom-git brave-bin zsh-fast-syntax-highlighting nerd-fonts-source-code-pro"
gitmakeprogs="https://github.com/deboogerxyz/dwm.git"
shell="zsh"

dotrepo="https://github.com/deboogerxyz/dotfiles.git"
dotbranch="master"
aurhelper="paru"

# Functions responsible for installing packages
installpkg() { \
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
	}

installaurpkg() { \
	"$aurhelper" --noconfirm --needed -S "$1" >/dev/null 2>&1
	}

# Refresh Arch and Artix keyring
refreshkeyring() { \
	dialog --infobox "Refreshing Arch keyring..." 4 30
	pacman -Q artix-keyring >/dev/null 2>&1 && pacman --noconfirm -S artix-keyring >/dev/null 2>&1
	pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
	}

# Update the system with pacman
updatesystem() { \
	dialog --infobox "Updating the system..." 4 30
	pacman --noconfirm --needed -Syu >/dev/null 2>&1
	}

installaurhelper() {
	dialog --infobox "Installing \`$aurhelper\` AUR helper..." 5 40
	cd /tmp
	rm -rf /tmp/"$aurhelper"
	git clone https://aur.archlinux.org/"$aurhelper".git || exit 1
	cd /tmp/"$aurhelper"
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp
	}

getuser() { \
	# Prompt user for username and password
	name=$(dialog --inputbox "Please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ; }

checkuser() { \
	! { id -u "$name" >/dev/null 2>&1; } ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "Cancel" --yesno "The user \`$name\` already exists.\\nThis script will override most of it's config files. Your important files will not be affected.\\n\\nAre you sure you want to continue?" 10 60
	}

# Add user $name with password $pass1
adduser() { \
	dialog --infobox "Adding user \`$name\`..." 4 50
	useradd -m -g wheel -s /bin/"$shell" "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
	}

# Install dotfiles
installdotfiles() { \
	dialog --infobox "Installing dotfiles..." 4 50
	dir=$(mktemp -d)
	[ ! -d "/home/$name" ] && mkdir -p "/home/$name"
	chown "$name":wheel "$dir" "/home/$name"
	sudo -u "$name" git clone --recursive -b "$dotbranch" --depth 1 --recurse-submodules "$dotrepo" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "/home/$name"
	rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"
	}

gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	rm -rf "$dir"
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 1 ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
	}

# Disable beep sound
disablebeep() { \
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
	}

# Install and set the default shell
setshell() { \
	installaurpkg "$1"
	chsh -s "/bin/$1" "$name" >/dev/null 2>&1
	}

# Install dialog for GUI
[ ! -x "$(command -v dialog)" ] && pacman --noconfirm --needed -Sy dialog

getuser
checkuser

# Use all cores for compilation
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

refreshkeyring
updatesystem

# Install the AUR helper if not already installed
[ ! -x "$(command -v $aurhelper)" ] && installaurhelper

# Install packages with pacman
for x in ${pkgs}; do
	total=$(echo $pkgs | wc -w)
	n=$((n+1))
	dialog --title "Installing package..." --infobox "Installing \`$x\` ($n of $total) package..." 5 70
	installpkg "$x"
done

# Allow users to use sudo
[ -f /etc/sudoers ] && grep -q "# %wheel ALL=(ALL) ALL" /etc/sudoers && sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers

adduser
installdotfiles
setshell "$shell"
disablebeep

# Make pacman look better
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Make paru look better
[ -f /etc/paru.conf ] && grep -q "#BottomUp" /etc/paru.conf && sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf

# Tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# Change trackpoint settings
[ ! -f /etc/udev/rules.d/10-trackpoint.rules ] && printf 'ACTION=="add", SUBSYSTEM=="input", ATTR{name}=="TPPS/2 IBM TrackPoint", ATTR{device/drift_time}="25", ATTR{device/sensitivity}="200"' > /etc/udev/rules.d/10-trackpoint.rules

# Start/restart PulseAudio.
killall pulseaudio; sudo -u "$user" pulseaudio --start

# Install AUR packages
for x in ${aurpkgs}; do
	total=$(echo $aurpkgs | wc -w)
	n=$((n+1))
	dialog --title "Installing AUR package..." --infobox "Installing \`$x\` ($n of $total) package from AUR..." 5 70
	installaurpkg "$x"
done

# Install programs via git and make
for x in ${gitmakeprogs}; do
	total=$(echo $gitmakeprogs | wc -w)
	n=$((n+1))
	dialog --title "Installing programs..." --infobox "Installing \`$x\` ($n of $total) via \`git\` and \`make\`..." 5 70
	gitmakeinstall "$x"
done
