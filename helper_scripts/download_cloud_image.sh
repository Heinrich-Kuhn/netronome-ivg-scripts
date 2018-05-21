#!/bin/bash

# This script will download a cloud image file and save it in $CLOUD_IMAGE_STORE.

# By default, it will download an Ubuntu image and store it in /root

# Default Image location (can be overruled below)
DEFAULT_UBUNTU_URL="https://cloud-images.ubuntu.com/releases/17.10/release"
DEFAULT_CENTOS_URL="https://cloud.centos.org/centos/7/images"
DEFAULT_UBUNTU_FILE="ubuntu-17.10-server-cloudimg-amd64.img"
DEFAULT_CENTOS_FILE="CentOS-7-x86_64-GenericCloud-1708.qcow2"

# This variable selects the OS of the VM image, and defaults to Ubuntu.
if [ "$CLOUD_IMAGE_OS" == "" ]; then
    CLOUD_IMAGE_OS="ubuntu"
fi

if [ "$CLOUD_IMAGE_STORE" == "" ]; then
    CLOUD_IMAGE_STORE="/root"
fi

case "$CLOUD_IMAGE_OS" in
  "centos")
    URL=${CENTOS_CLOUD_IMAGE_URL-"$DEFAULT_CENTOS_URL"}
    FILE=${CENTOS_CLOUD_IMAGE_FILE-"$DEFAULT_CENTOS_FILE"}
    ;;
  "ubuntu")
    URL=${UBUNTU_CLOUD_IMAGE_URL-"$DEFAULT_UBUNTU_URL"}
    FILE=${UBUNTU_CLOUD_IMAGE_FILE-"$DEFAULT_UBUNTU_FILE"}
    ;;
esac

if [ ! -f "$CLOUD_IMAGE_STORE/$FILE" ]; then
    echo " - Download $FILE"

    # Store the file under a different name while being downloaded
    tmpfile="$CLOUD_IMAGE_STORE/.pending-$FILE"

    wget --continue "$URL/$FILE" -O $tmpfile
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to download $URL/$FILE"
        exit -1
    fi

    mv $tmpfile $CLOUD_IMAGE_STORE/$FILE \
        || exit -1
fi

echo " - Update Servers with Cloud Image file"
$IVG_dir/helper_scripts/rsync-servers.sh \
    $CLOUD_IMAGE_STORE/$FILE \
    /var/lib/libvirt/images \
    || exit -1

exit 0
