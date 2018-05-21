#!/bin/bash

DEFAULT_CENTOS_URL="https://cloud.centos.org/centos/7/images"
DEFAULT_CENTOS_FILE="CentOS-7-x86_64-GenericCloud-1708.qcow2"

URL=${CENTOS_CLOUD_IMAGE_URL-"$DEFAULT_CENTOS_URL"}
FILE=${CENTOS_CLOUD_IMAGE_FILE-"$DEFAULT_CENTOS_FILE"}

LIBVIRT_DIR=/var/lib/libvirt/images

if [ ! -f "$LIBVIRT_DIR/$FILE" ]; then
    echo " - Download $FILE"

    # Store the file under a different name while being downloaded
    tmpfile="$LIBVIRT_DIR/.pending-$FILE"

    wget --continue "$URL/$FILE" -O $tmpfile
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to download $URL/$FILE"
        exit -1
    fi

    mv $tmpfile $LIBVIRT_DIR/$FILE \
        || exit -1
fi

exit 0
