#!/bin/bash

for mode in shutdown destroy undefine ; do

    case $mode in
        shutdown)
            filter="--state-running"
            timeout=15
            ;;
        destroy)
            filter="--state-running --state-paused"
            timeout=5
            ;;
        undefine)
            filter="--all"
            timeout=20
            ;;
    esac

    vmlist=( $(virsh list $filter \
        | sed -rn 's/^.*\s(netronome\S+)\s.*$/\1/p' ) )

    for vmname in ${vmlist[@]} ; do
        echo " - $mode VM $vmname"
        virsh $mode $vmname > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "WARNING: failed to $mode $vmname"
        fi
    done

    while [ ${#vmlist[@]} -gt 0 ] && [ $(( timeout-- )) -gt 0 ] ; do

        sleep 1

        vmlist=( $(virsh list $filter \
            | sed -rn 's/^.*\s(netronome\S+)\s.*$/\1/p' ) )
    done

done

exit 0
