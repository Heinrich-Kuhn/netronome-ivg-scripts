#!/bin/bash

ADD="$(grep -n 'libxl-save-helper' /etc/apparmor.d/usr.sbin.libvirtd | cut -d: -f1)"
OUT="$(grep -n '/usr/local/bin/qemu* PUx,' /etc/apparmor.d/usr.sbin.libvirtd | cut -d: -f1)"
[ -z "$OUT" ] && sed -i "$ADD a /usr/local/bin/qemu* PUx, #ADD OVS" /etc/apparmor.d/usr.sbin.libvirtd
OUT="$(grep -n '/usr/local/bin/ovs-vsctl rmix,' /etc/apparmor.d/usr.sbin.libvirtd | cut -d: -f1)"
[ -z "$OUT" ] && sed -i "$ADD a /usr/local/bin/ovs-vsctl rmix, #ADD OVS" /etc/apparmor.d/usr.sbin.libvirtd

OUT="$(grep -n "deny /tmp/" /etc/apparmor.d/abstractions/libvirt-qemu | cut -d: -f1)"
sed -i "$OUT s/^/#/" /etc/apparmor.d/abstractions/libvirt-qemu
OUT="$(grep -n "deny /var/tmp/" /etc/apparmor.d/abstractions/libvirt-qemu | cut -d: -f1)"
sed -i "$OUT s/^/#/" /etc/apparmor.d/abstractions/libvirt-qemu

sudo service apparmor reload
