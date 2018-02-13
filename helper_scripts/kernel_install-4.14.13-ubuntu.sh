#!/bin/bash
script_dir="$(dirname $(readlink -f $0))"

wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14.13/linux-headers-4.14.13-041413_4.14.13-041413.201801101001_all.deb
wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14.13/linux-headers-4.14.13-041413-generic_4.14.13-041413.201801101001_amd64.deb
wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14.13/linux-image-4.14.13-041413-generic_4.14.13-041413.201801101001_amd64.deb

dpkg -i linux-headers-4.14.13-041413_4.14.13-041413.201801101001_all.deb
dpkg -i linux-headers-4.14.13-041413-generic_4.14.13-041413.201801101001_amd64.deb
dpkg -i linux-image-4.14.13-041413-generic_4.14.13-041413.201801101001_amd64.deb

apt-get -f install

$script_dir/configure_grub.sh

update-grub2

echo "PLEASE REBOOT MACHINE"

sleep 5
