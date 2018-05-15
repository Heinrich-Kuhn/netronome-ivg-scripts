#!/bin/bash

source="$1"
target="$2"

sshopts=()
sshopts+=( "-l" "root" )
sshopts+=( "-i" "$HOME/.ssh/netronome_key" )
sshcmd="ssh ${sshopts[@]}"

for ipaddr in $IVG_SERVERS_IPADDR_LIST ; do

    rsync -a -q -e "$sshcmd" $source $ipaddr:$target

    if [ $? -ne 0 ]; then
        echo "ERROR: failed to update $ipaddr"
        exit -1
    fi

done

exit 0
