#!/bin/bash

if [ -f "$1" ]; then
    pkgfile="$1"
elif [ -d "$1" ]; then
    pkgdir="$1"
elif [ "$1" != "" ]; then
    version="$1"
else
    echo "Usage: <DPDK package file>|<DPDK version>"
    exit -1
fi

########################################

pkgname="dpdk"

# Installation Directory
srcdir="/opt/src"

# Compile Target Architecture for DPDK
export RTE_TARGET="x86_64-native-linuxapp-gcc"

########################################

function check_status () {
    rc="$?" ; errmsg="$1"
    if [ "$rc" != "0" ]; then
        echo "ERROR: $errmsg"
        exit -1
    fi
}

########################################
##  Install pre-requisites (assuming the tool is available)

prereqs=()
prereqs+=( "wget@" )
prereqs+=( "tar@" )
prereqs+=( "sed@" )
prereqs+=( "gcc@build-essential" )
prereqs+=( "make@build-essential" )
prereqs+=( "/usr/include/libelf.h@libelf-dev" )

$IVG_dir/helper_scripts/install-packages.sh ${prereqs[@]}
    check_status "failed to install prerequisites"

########################################
##  Try to find a local DPDK package

srchlist=()
srchlist+=( "$(pwd)" )
srchlist+=( "$HOME" )
srchlist+=( "/opt/download" )
srchlist+=( "/pkgs/dpdk" )
srchlist+=( "/tmp" )

if [ "$pkgfile" == "" ] && [ "$pkgdir" == "" ]; then
    for srchdir in ${srchlist[@]} ; do
        if [ -d "$srchdir" ]; then
            fn=$(find $srchdir -type f -name "$pkgname-$version.tar*" \
                | head -1)
            if [ "$fn" != "" ]; then
                pkgfile="$fn"
                break
            fi
        fi
    done
fi

########################################

if [ "$pkgfile" == "" ] && [ "$pkgdir" == "" ]; then
    dldir="/opt/download"
    url="https://fast.dpdk.org/rel"
    fname="$pkgname-$version.tar.xz"
    mkdir -p $dldir
        check_status "failed to create $dldir"
    dlfile="$dldir/pend-$fname"
    echo " - Downloading $url/$fname"
    wget --no-verbose "$url/$fname" -O "$dlfile"
        check_status "failed to download $url/$fname"
    pkgfile="$dldir/$fname"
    /bin/mv -f "$dlfile" "$pkgfile"
        check_status "failed to move $dlfile"
fi

########################################

if [ "$version" == "" ]; then
    if [ "$pkgfile" != "" ]; then
        version=$(echo $pkgfile \
            | sed -r 's/^.*\/'$pkgname'-(\S+)\.tar.*$/\1/')
    elif [ -d $pkgdir/.git ]; then
        version=$(cd $pkgdir ; git log -1 --format="%H")
    else
        version=""
    fi
fi

########################################

if [ "$pkgdir" == "" ]; then
    mkdir -p $srcdir

    tar x -C $srcdir -f $pkgfile
        check_status "failed to un-tar $pkgfile"

    tardir=$(tar t -f $pkgfile \
        | head -1 \
        | sed -r 's/\/$//')

        check_status "failed to determine package directory"

    pkgdir="$srcdir/$tardir"
fi

export RTE_SDK="$pkgdir"

########################################

opts=""
opts="$opts T=$RTE_TARGET"

########################################

# Needed for DPDK-DAQ installation:
if [ "$BUILD_FOR_DPDK_DAQ" != "" ]; then
    echo "export EXTRA_CFLAGS=-O0 -fPIC -g" \
        >> $RTE_SDK/mk/rte.vars.mk
    opts="$opts CONFIG_RTE_BUILD_COMBINE_LIBS=y"
    opts="$opts CONFIG_RTE_BUILD_SHARED_LIB=y"
    opts="$opts EXTRA_CFLAGS=\"-fPIC\""
fi

########################################

make -C $RTE_SDK config $opts

    check_status "failed to configure DPDK"

########################################

sed -r 's/(CONFIG_RTE_LIBRTE_NFP_PMD)=.*$/\1=y/' \
    -i $RTE_SDK/build/.config

########################################

make -C $RTE_SDK

    check_status "failed to make DPDK"

########################################

# Not sure why this is needed, but I can't build other apps without it:
if [ ! -h $RTE_SDK/$RTE_TARGET ]; then
    ln -sf $RTE_SDK/build $RTE_SDK/$RTE_TARGET
fi

########################################
##  Save DPDK settings

conffile="/etc/$pkgname-$version.conf"

( \
    echo "# Generated on $(date) by $0" ; \
    echo "export RTE_SDK=\"$RTE_SDK\"" ; \
    echo "export RTE_TARGET=\"$RTE_TARGET\"" ; \
    echo "export DPDK_VERSION=\"$version\"" ; \
) > $conffile

/bin/cp -f $conffile /etc/$pkgname.conf

########################################

exit 0
