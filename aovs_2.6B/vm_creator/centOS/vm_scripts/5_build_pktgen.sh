#!/bin/bash

. /etc/dpdk.conf || exit -1

srcdir="/opt/src"
pkgdir="/opt/pkg"
mkdir -p $srcdir $pkgdir || exit -1

PKTGEN="pktgen-dpdk-pktgen-3.3.2"

if [ ! -f "$pkgdir/$PKTGEN.tar.gz" ]; then
    echo "Downloading $PKTGEN"
    wget http://dpdk.org/browse/apps/pktgen-dpdk/snapshot/$PKTGEN.tar.gz \
        --directory-prefix=$pkgdir \
        || exit -1
fi

tar xf $pkgdir/$PKTGEN.tar.gz -C $srcdir \
    || exit -1

#Change MAX_MBUFS_PER_PORT * 8 to 32 for more flows per port
sed -i '/.*number of buffers to support per port.*/c\\tMAX_MBUFS_PER_PORT\t= (DEFAULT_TX_DESC * 32),/* number of buffers to support per port */' \
    $srcdir/$PKTGEN/app/pktgen-constants.h \
    || exit -1

make -C $srcdir/$PKTGEN \
    || exit -1

ln -s $srcdir/$PKTGEN/app/app/x86_64-native-linuxapp-gcc/pktgen \
    $RTE_SDK/dpdk-pktgen \
    || exit -1

exit 0
