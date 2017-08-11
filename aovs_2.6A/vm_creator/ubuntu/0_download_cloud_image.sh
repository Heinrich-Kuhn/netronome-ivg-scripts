#!/bin/bash

#This script will download a ubuntu cloud image (300Mb) and save it in /var/lib/libvirt/images/
#It will create a copy of the cloud image as a backup with the suffix .copy

GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'


UBUNTU_CLOUD_IMAGE=ubuntu-16.04-server-cloudimg-amd64-disk1.img
UBUNTU_CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/releases/16.04/release/$UBUNTU_CLOUD_IMAGE
cd /var/lib/libvirt/images/

if [ -f $UBUNTU_CLOUD_IMAGE.copy ]; then
	echo -e "${GREEN}Using ubuntu cloud-image .copy as base image${NC}" 
	read -p "Do you want to remove previous backing image, this will render VM's using this backing image useless? (y/n): " ans1
        if [ $ans1 == "y" ]
        then
            rm -f $UBUNTU_CLOUD_IMAGE
            cp $UBUNTU_CLOUD_IMAGE.copy $UBUNTU_CLOUD_IMAGE
        else
            exit 1
        fi
else
	cd /var/lib/libvirt/images/
	echo -e "${GREEN}Downloading ubuntu-16.04-server-cloudimg-amd64-disk1.img to /var/lib/libvirt/images/${NC}"
	wget --timestamping $UBUNTU_CLOUD_IMAGE_URL
	echo -e "${GREEN}Creating copy of ubuntu-cloud-image${NC}"
	cp ubuntu-16.04-server-cloudimg-amd64-disk1.img ubuntu-16.04-server-cloudimg-amd64-disk1.img.copy
fi





