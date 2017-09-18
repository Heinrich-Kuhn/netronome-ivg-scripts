#!/bin/bash

srcdir="/opt/src/Tools"
mkdir -p $srcdir || exit -1

url="https://github.com/netronome-support/Tools"

if [ -d $srcdir/.git ]; then
    ( cd $srcdir && git pull ) || exit -1
else
    git clone $url $srcdir || exit -1
fi

tooldir="$srcdir/dpdk"
toollist=$(find $srcdir/dpdk -mindepth 1 -maxdepth 1 -type d)

# For now, hard-code these values here (a better solution is needed):
export RTE_SDK="/root/dpdk-16.11"
export RTE_TARGET="x86_64-native-linuxapp-gcc"

for tooldir in $toollist ; do
    toolname=$(basename $tooldir)
    make -C $tooldir || exit -1
    cp $tooldir/build/$toolname /usr/local/bin || exit -1
done

exit 0
