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

echo " - Collect System Inventory"
$IVG_dir/helper_scripts/inventory.sh \
    > $logdir/inventory.log 2>&1 \
    || exit -1

echo " - Setup Hugepages"
$IVG_dir/helper_scripts/configure_hugepages.sh \
    || exit -1

echo "DONE($(basename $0))"

exit 0
