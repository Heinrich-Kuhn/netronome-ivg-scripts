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
: "${DPDK_INSTALL_DIR:=/opt/src}"

# Compile Target Architecture for DPDK
: "${RTE_TARGET:=x86_64-native-linuxapp-gcc}"

# DPDK Download Directory
: "${DPDK_DOWNLOAD_DIR:=/var/cache/download}"

# DPDK Web Site
: "${DPDK_DOWNLOAD_URL:=https://fast.dpdk.org/rel}"

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

kvers=$(uname -r)

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
srchlist+=( "$DPDK_DOWNLOAD_DIR" )
srchlist+=( "/var/cache/download" )
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
    fname="$pkgname-$version.tar.xz"
    mkdir -p $DPDK_DOWNLOAD_DIR
        check_status "failed to create $DPDK_DOWNLOAD_DIR"
    dlfile="$DPDK_DOWNLOAD_DIR/pend-$fname"
    echo " - Downloading $DPDK_DOWNLOAD_URL/$fname"
    wget --no-verbose "$DPDK_DOWNLOAD_URL/$fname" -O "$dlfile"
        check_status "failed to download $DPDK_DOWNLOAD_URL/$fname"
    pkgfile="$DPDK_DOWNLOAD_DIR/$fname"
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
    mkdir -p $DPDK_INSTALL_DIR

    tar x -C $DPDK_INSTALL_DIR -f $pkgfile
        check_status "failed to un-tar $pkgfile"

    tardir=$(tar t -f $pkgfile \
        | head -1 \
        | sed -r 's/\/$//')

        check_status "failed to determine package directory"

    pkgdir="$DPDK_INSTALL_DIR/$tardir"
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

ss=""
ss="${ss}"'s/(CONFIG_RTE_LIBRTE_NFP_PMD)=.*$/\1=y/;'

########################################
# Custom configuration (via DPDK_CUSTOM_CONFIG)

idx=1
while : ; do
    config=$(echo "$DPDK_CUSTOM_CONFIG;" | cut -d ';' -f $idx)
    if [ "$config" == "" ]; then
        break
    fi
    varname=${config/=*/}
    value=${config/*=/}
    if [ "$varname" != "" ] && [ "$value" != "" ]; then
        ss="${ss}s/($varname)=.*\$/\1=$value/;"
    fi
    idx=$(( idx + 1 ))
done

########################################
sed -r "$ss" -i $RTE_SDK/build/.config \
    || exit -1

########################################
# Save a copy of the configuration

buildconfig="$RTE_SDK/build/build.config"

if [ -f $buildconfig ]; then
    /bin/mv -f $buildconfig $buildconfig.old \
        || exit -1
fi
/bin/cp -f $RTE_SDK/build/.config \
    ${buildconfig}.pending \
    || exit -1

########################################

make -C $RTE_SDK \
    | tee $RTE_SDK/build/make.log

    check_status "failed to make DPDK"

########################################

make -C $RTE_SDK install

    check_status "failed to install DPDK"

########################################
# Move the pending build config

/bin/mv ${buildconfig}.pending $buildconfig \
    || exit -1

########################################

depmod -a

########################################

# Not sure why this is needed, but I can't build other apps without it:
if [ ! -h $RTE_SDK/$RTE_TARGET ]; then
    ln -sf $RTE_SDK/build $RTE_SDK/$RTE_TARGET
fi

########################################

devbind=$(find $RTE_SDK -name 'dpdk-devbind.py' \
    | head -1)

if [ -f "$devbind" ]; then
    cp -f $devbind /usr/local/bin

        check_status "failed to copy dpdk-devbind.py"
fi

########################################
##  Save DPDK settings

conffile="/etc/$pkgname-$version.conf"

( \
    echo "# Generated on $(date) by $0" ; \
    echo "export RTE_SDK=\"$RTE_SDK\"" ; \
    echo "export RTE_TARGET=\"$RTE_TARGET\"" ; \
    echo "export DPDK_VERSION=\"$version\"" ; \
    echo "export DPDK_DEVBIND=\"$devbind\"" ; \
    echo "export DPDK_CONFIG=\"$buildconfig\"" ; \
) > $conffile

/bin/cp -f $conffile /etc/$pkgname.conf

########################################

exit 0
