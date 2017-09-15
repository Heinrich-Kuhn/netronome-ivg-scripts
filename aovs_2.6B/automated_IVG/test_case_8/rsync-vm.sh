#!/bin/bash

VM_NAME=$1
shift 1
sshargs="$@"

sshopts=()
sshopts+=( "-o" "StrictHostKeyChecking=no" )
sshopts+=( "-o" "ConnectionAttempts=200" )
sshcmd="ssh ${sshopts[@]}"

ipafile="/var/run/vm/$VM_NAME.ipaddr"
if [ ! -f $ipafile ]; then
    echo "ERROR: missing IP address for VM (in $ipafile)"
    exit -1
fi

ipaddr=$(cat $ipafile)

if [ "$ipaddr" == "" ]; then
    echo "ERROR: empty IP address in file ($ipafile)"
    exit -1
fi

nc $ipaddr 22 < /dev/null > /dev/null
if [ "$?" != "0" ]; then
    echo "ERROR: can not reach VM at $ipaddr"
    exit -1
fi

ropts=()
ropts+=( "-e" "$sshcmd -l root" )

exec rsync "${ropts[@]}" -a \
    $HOME/IVG_folder/vm_creator/ubuntu/vm_scripts \
    $ipaddr:
