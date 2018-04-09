#!/bin/bash

key_file="$HOME/.ssh/netronome_key"

if [ ! -f $key_file ]; then
    echo " - Create Public key"
    ssh-keygen -t rsa -f $key_file -q -P ""
    ssh-add $key_file
fi

logfile=$(mktemp --suffix='-ssh-copy.log')

for ipaddr in $@ ; do
    echo " - Copy Public Key to $ipaddr"
    date > $logfile
    echo "IP address: $ipaddr" >> $logfile
    ssh-copy-id -i $key_file.pub root@$ipaddr \
        >> $logfile 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR($0): failed to copy SSH key to DUT($ipaddr)"
        cat $logfile
        exit -1
    fi
done

rm $logfile

exit 0
