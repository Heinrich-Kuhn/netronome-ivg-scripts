#!/bin/bash

# Disable entry that associates 'eth0' with the original MAC address
echo -n > /etc/udev/rules.d/70-persistent-net.rules

# The management interface will have a different MAC address
# when being reused. If the HWADDR entry is left, the interface will
# not come up.
sed -r '/^HWADDR=/d' \
    -i /etc/sysconfig/network-scripts/ifcfg-eth0 \
    || exit -1

# Blacklist the 'nfp' driver so that the management port (00:02.0) is
# always named 'eth0'. Not sure why the nfp driver sometimes causes
# management interface to be named elsewise.
sed -r 's/^(GRUB_CMDLINE_LINUX=\".*)\"$/\1 modprobe.blacklist=nfp\"/' \
    -i /etc/default/grub \
    || exit -1

grub2-mkconfig --output /boot/grub2/grub.cfg \
    || exit -1

exit 0
