#!/bin/bash

BASE_URL="https://github.com/rapiz1/rathole/releases/latest/download/"
BINARIES=( "aarch64-unknown-linux-musl" "arm-unknown-linux-musleabi" "arm-unknown-linux-musleabihf" \
	"armv7-unknown-linux-musleabihf" "mips-unknown-linux-gnu" "mips-unknown-linux-musl" \
	"mips64-unknown-linux-gnuabi64" "mips64el-unknown-linux-gnuabi64" "mipsel-unknown-linux-gnu" \
	"mipsel-unknown-linux-musl" "x86_64-apple-darwin" "x86_64-pc-windows-msvc" \
	"x86_64-unknown-linux-gnu" )
BINARIES_LEN=${#BINARIES[@]}
SERVICE_FILE="/etc/systemd/system/rathole.service"
INSTALL_DIR="/usr/bin"
CONFIG_DIR="/etc/rathole"

print_binaries () {
	echo "Available binaries:"
	for (( i=0; i < $BINARIES_LEN; i++ )); do
		echo "  $(($i + 1))) ${BINARIES[$i]}"
	done
}

print_help () {
	printf "Usage:\n"
	printf "%s [COMMAND]\n" $0
	printf "Commands:\n"
	printf "\tinstall [binary-version] - Install rathole binary, if version is not given, interactive prompt will ask you\n"
	printf "\tuninstall\n"
	printf "\tpurge - Uninstalls Rathole and removes all configuration files\n"
	printf "\tlist\n"
}

loge () {
	echo "[-] $1"
}

logi () {
	echo "[+] $1"
}

logw () {
	echo "[*] $1"
}

print_service () {
echo "[Unit]
Description=Rathole service
After=network.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=$INSTALL_DIR/rathole $CONFIG_DIR/config.toml
[Install]
WantedBy=multi-user.target"
}

check_root () {
	[ "$UID" -eq 0 ] || { logw "This script must be run as root."; exit 1;}
}

install () {
		check_root
		SEL=$1
		if [[ -z "$SEL" ]]; then
			print_binaries
			printf "Select binary to install: "
			read -r SEL 
		fi
		
		SEL=$(( $SEL - 1 ))

		if [[ $SEL -lt "0" || $SEL -ge $BINARIES_LEN ]]; then
			loge "Invalid binary selected"
			print_help $0
			exit 1
		fi

		SEL_FILE=${BINARIES[$SEL]}

		logi "Downloading Rathole $SEL_FILE"
		wget "${BASE_URL}rathole-${SEL_FILE}.zip" -O /tmp/rathole.zip
		cd /tmp
		unzip rathole.zip -d rathole	
		logi "Installing Rathole to $INSTALL_DIR"
		sudo cp rathole/rathole $INSTALL_DIR/rathole
		rm -R rathole rathole.zip
		logi "Creating config direction $CONFIG_DIR"
		sudo mkdir $CONFIG_DIR 
		sudo touch $CONFIG_DIR/config.toml
		logi "Creating service"
		print_service | sudo tee $SERVICE_FILE >/dev/null
		systemctl daemon-reload
		logi "Enabling service"
		systemctl enable rathole
		logi "Starting service"
		systemctl start rathole
		logi "Rathole has been successfully installed"
}

uninstall () {
		check_root
		logi "Stopping service"
		systemctl stop rathole
		logi "Removing rathole binary $INSTALL_DIR/rathole"
		sudo rm $INSTALL_DIR/rathole
		logi "Removing service"
		systemctl disable rathole
		sudo rm -R $SERVICE_FILE
		systemctl daemon-reload
		logi "Rathole has been successfully uninstalled"
}

purge () {
	check_root
	logi "Removing config directory $CONFIG_DIR"
	sudo rm -R $CONFIG_DIR
	uninstall
}

case "$1" in
	install)
		install $2
		;;
	uninstall)
		uninstall
		exit
		;;
	purge)
		purge
		exit
		;;
	list)
		print_binaries
		exit
		;;
	*)
		loge "Invalid command"
		print_help $0
		exit 1
esac
