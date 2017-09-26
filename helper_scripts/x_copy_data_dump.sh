#!/bin/bash

ip=$(arp -an | grep $(virsh dumpxml $1 | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')
echo test
scp root@$ip:/root/capture.txt /root/IVG_folder/
scp root@$ip:/root/parsed_data.txt /root/IVG_folder/


