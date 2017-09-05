#!/bin/bash

#Get script path
script_dir="$(dirname $(readlink -f $0))"

#Colour ANSI codes
GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'



VM_NAME=centos_backing
CENTOS_CLOUD_IMAGE_XZ=CentOS-7-x86_64-GenericCloud.qcow2.xz
CENTOS_CLOUD_IMAGE=CentOS-7-x86_64-GenericCloud.qcow2
CENTOS_CLOUD_IMAGE_URL=https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz

cd /var/lib/libvirt/images/

if [ -f $CENTOS_CLOUD_IMAGE.copy ]; then
	echo -e "${GREEN}Using centos cloud-image .copy as base image${NC}" 
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
        echo -e "${GREEN}Downloading CentOS-7-x86_64-GenericCloud.qcow2.xz to /var/lib/libvirt/images/${NC}"
        wget --timestamping $CENTOS_CLOUD_IMAGE_URL
        echo -e "${GREEN}Decompressing .xz file...${NC}"
        unxz -k -v $CENTOS_CLOUD_IMAGE_XZ
	echo -e "${GREEN}Creating copy of cloud image${NC}"
	cp $CENTOS_CLOUD_IMAGE $CENTOS_CLOUD_IMAGE.copy
fi

