#!/bin/bash

#This script will download a CentOS cloud image (300Mb) and save it in /var/lib/libvirt/images/
#It will create a copy of the cloud image as a backup with the suffix .copy

GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'

CENTOS_CLOUD_IMAGE=CentOS-7-x86_64-GenericCloud-1708.qcow2
CENTOS_CLOUD_IMAGE_URL=https://cloud.centos.org/centos/7/images/$CENTOS_CLOUD_IMAGE
LIBVIRT_DIR=/var/lib/libvirt/images

cd $LIBVIRT_DIR 

if [ -f $CENTOS_CLOUD_IMAGE.copy ]; then
	echo -e "${GREEN}Using CentOS cloud-image .copy as base image${NC}" 
	read -p "Do you want to remove previous backing image, this will render VM's using this backing image useless? (y/n): " ans1
        if [ $ans1 == "y" ]
        then
            rm -f $CENTOS_CLOUD_IMAGE
            cp $CENTOS_CLOUD_IMAGE.copy $CENTOS_CLOUD_IMAGE
        else
            exit 1
        fi
else
    cd /var/lib/libvirt/images/
	echo -e "${GREEN}CentOS-7-x86_64-GenericCloud-1708.qcow2 to /var/lib/libvirt/images/${NC}"
    wget --timestamping $CENTOS_CLOUD_IMAGE_URL
    echo -e "${GREEN}Creating copy of centos-cloud-image${NC}"
	cp  $CENTOS_CLOUD_IMAGE $CENTOS_CLOUD_IMAGE.copy
fi


USERNAME=root
CENTOS_CLOUD_IMAGE=CentOS-7-x86_64-GenericCloud-1708.qcow2
CENTOS_CLOUD_IMAGE_URL=https://cloud.centos.org/centos/7/images/$CENTOS_CLOUD_IMAGE
LIBVIRT_DIR=/var/lib/libvirt/images




