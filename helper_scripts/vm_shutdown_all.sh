#!/bin/bash

vmlist=( $(virsh list --state-running \
    | sed -rn 's/^.*(netronome\S+)\s+running$/\1/p' ) )

for vmname in ${vmlist[@]} ; do
    echo "Shutdown $vmname"
    virsh shutdown $vmname > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "WARNING: failed to shutdown $vmname"
    fi
done

if [ ${#vmlist[@]} -gt 0 ]; then
    sleep 4
fi

vmlist=( $(virsh list --state-running \
    | sed -rn 's/^.*(netronome\S+)\s+running$/\1/p' ) )

await=
for vmname in ${vmlist[@]} ; do
    echo "Destroy $vmname"
    virsh destroy $vmname > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "WARNING: failed to destroy $vmname"
    fi
    await="yes"
done

if [ ${#vmlist[@]} -gt 0 ]; then
    sleep 1
fi

vmlist=( $(virsh list --all \
    | sed -rn 's/^.*(netronome\S+)\s+.*$/\1/p' ) )

for vmname in ${vmlist[@]} ; do
    echo "Undefine $vmname"
    virsh undefine $vmname > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "WARNING: failed to undefine $vmname"
    fi
done

if [ ${#vmlist[@]} -gt 0 ]; then
    sleep 1
fi

exit 0
