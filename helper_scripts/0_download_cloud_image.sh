#!/bin/bash

#This script will download a ubuntu cloud image (300Mb) and save it in /root/
#It will create a copy of the cloud image as a backup with the suffix .copy

GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'


UBUNTU_CLOUD_IMAGE=ubuntu-16.04-server-cloudimg-amd64-disk1.img
UBUNTU_CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/releases/16.04/release/$UBUNTU_CLOUD_IMAGE


echo -e "${GREEN}Downloading ubuntu-16.04-server-cloudimg-amd64-disk1.img to working directory${NC}"
cd /root/
wget --timestamping $UBUNTU_CLOUD_IMAGE_URL






