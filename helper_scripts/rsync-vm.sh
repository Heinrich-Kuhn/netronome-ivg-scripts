#!/bin/bash

# This script should be run on the servers and will update the vm_scripts
# inside of the specified VM. This might come in handy when debugging
# scripts.

vmname=$1

if [ "$vmname" == "" ]; then
    echo "ERROR: missing VM name"
    exit -1
fi

sshopts=()
sshopts+=( "-q" )
sshopts+=( "-o" "StrictHostKeyChecking=no" )
sshopts+=( "-o" "UserKnownHostsFile=/dev/null" )
#sshopts+=( "-i" "$HOME/.ssh/netronome_key" )
sshopts+=( "-o" "ConnectionAttempts=200" )
sshopts+=( "-l" "root" )
sshcmd="ssh ${sshopts[@]}"

get_tool="/root/IVG_folder/helper_scripts/get-vm-ipaddr.sh"
msg=$($get_tool $vmname)
if [ $? -ne 0 ]; then
    echo "$msg"
    exit -1
fi

ipaddr="$msg"

$sshcmd $ipaddr "true"
if [ "$?" != "0" ]; then
    echo "ERROR: can not SSH to VM at $ipaddr"
    exit -1
fi

ropts=()
ropts+=( "-e" "$sshcmd" )

exec rsync "${ropts[@]}" -a \
    $HOME/IVG_folder/vm_scripts \
    $ipaddr:
