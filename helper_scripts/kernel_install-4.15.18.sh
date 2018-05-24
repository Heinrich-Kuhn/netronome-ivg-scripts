#!/bin/bash
script_dir="$(dirname $(readlink -f $0))"

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    #wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14.13/linux-headers-4.14.13-041413_4.14.13-041413.201801101001_all.deb
    #wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14.13/linux-headers-4.14.13-041413-generic_4.14.13-041413.201801101001_amd64.deb
    #wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.14.13/linux-image-4.14.13-041413-generic_4.14.13-041413.201801101001_amd64.deb
    #wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.3/linux-image-4.15.3-041503-generic_4.15.3-041503.201802120730_amd64.deb
    #wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.3/linux-headers-4.15.3-041503-generic_4.15.3-041503.201802120730_amd64.deb
    #wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.3/linux-headers-4.15.3-041503_4.15.3-041503.201802120730_all.deb
    wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.18/linux-headers-4.15.18-041518_4.15.18-041518.201804190330_all.deb
    wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.18/linux-headers-4.15.18-041518-generic_4.15.18-041518.201804190330_amd64.deb
    wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.15.18/linux-image-4.15.18-041518-generic_4.15.18-041518.201804190330_amd64.deb

    dpkg -i linux-image-4.15.18-041518-generic_4.15.18-041518.201804190330_amd64.deb
    dpkg -i linux-headers-4.15.18-041518-generic_4.15.18-041518.201804190330_amd64.deb
    dpkg -i linux-headers-4.15.18-041518_4.15.18-041518.201804190330_all.deb

	apt-get install aptitude
    aptitude -f install

    $script_dir/configure_grub.sh

    update-grub2
fi


grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then

    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm 

    yum --disablerepo="*" --enablerepo="elrepo-kernel" list available

    yum --enablerepo=elrepo-kernel -y install kernel-ml

    sed -i 's#^GRUB_DEFAULT=.*#GRUB_DEFAULT=0#g' /etc/default/grub

    $script_dir/configure_grub.sh

    grub2-mkconfig -o /boot/grub2/grub.cfg

fi


echo "PLEASE REBOOT MACHINE"

sleep 5
exit 0

