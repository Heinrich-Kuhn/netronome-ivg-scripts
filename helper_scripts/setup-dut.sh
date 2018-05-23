#!/bin/bash

if [ "$IVG_dir" == "" ]; then
    echo "ERROR($0): missing \$IVG_dir variable"
    exit -1
fi

if [ ! -d "$IVG_dir" ]; then
    echo "ERROR($0): missing $IVG_dir directory"
    exit -1
fi

mkdir -p $IVG_dir/aovs_2.6B \
    || exit -1

if [ "$logdir" != "" ]; then
    mkdir -p $logdir \
        || exit -1
fi

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    # Run 'apt-get update' if it has not been run recently
    if test $(find /var/lib/apt -type d -name 'lists' -mmin +10080) ; then
        apt-get update \
            || exit -1
    fi
fi

echo " - Collect System Inventory"
$IVG_dir/helper_scripts/inventory.sh \
    > $logdir/inventory.log 2>&1 \
    || exit -1

echo "DONE($(basename $0))"

exit 0
