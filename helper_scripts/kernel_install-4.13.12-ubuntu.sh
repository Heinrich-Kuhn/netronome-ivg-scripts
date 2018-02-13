#!/bin/bash

cd /tmp

script_dir="$(dirname $(readlink -f $0))"

# wget --timestamping http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14-rc7/linux-headers-4.14.0-041400rc7_4.14.0-041400rc7.201711051952_all.deb
# wget --timestamping http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14-rc7/linux-headers-4.14.0-041400rc7-generic_4.14.0-041400rc7.201711051952_amd64.deb
# wget --timestamping http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14-rc7/linux-image-4.14.0-041400rc7-generic_4.14.0-041400rc7.201711051952_amd64.deb

wget --timestamping http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.13.12/linux-headers-4.13.12-041312-generic_4.13.12-041312.201711080535_amd64.deb
wget --timestamping http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.13.12/linux-headers-4.13.12-041312_4.13.12-041312.201711080535_all.deb
wget --timestamping http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.13.12/linux-image-4.13.12-041312-generic_4.13.12-041312.201711080535_amd64.deb

#dpkg -i linux-image-4.14.0-041400rc7-generic_4.14.0-041400rc7.201711051952_amd64.deb
#dpkg -i linux-headers-4.14.0-041400rc7-generic_4.14.0-041400rc7.201711051952_amd64.deb
#dpkg -i linux-headers-4.14.0-041400rc7_4.14.0-041400rc7.201711051952_all.deb

dpkg -i linux-image-4.13.12-041312-generic_4.13.12-041312.201711080535_amd64.deb
dpkg -i linux-headers-4.13.12-041312-generic_4.13.12-041312.201711080535_amd64.deb
dpkg -i linux-headers-4.13.12-041312_4.13.12-041312.201711080535_all.deb

apt-get -f install

$script_dir/configure_grub.sh

update-grub2


echo "PLEASE REBOOT MACHINE"
sleep 5
