#!/bin/bash



grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
    # rpms
    yum install yum-plugin-copr
    yum copr enable netronome/virtio-forwarder
    yum install virtio-forwarder
fi

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    # debs
    add-apt-repository -y ppa:netronome/virtio-forwarder
    apt-get -y update
    apt-get -y install virtio-forwarder
fi

# Start virtio-forwarder

systemctl start virtio-forwarder # systemd




