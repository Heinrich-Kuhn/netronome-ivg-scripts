#!/bin/bash

. /etc/dpdk.conf || exit -1

srcdir="/opt/src"
pkgdir="/opt/pkg"
mkdir -p $srcdir $pkgdir || exit -1

PKTGEN="pktgen-dpdk-pktgen-3.3.2"

export RTE_OUTPUT="/root/pktgen"
mkdir -p $RTE_OUTPUT

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

cat <<EOF > /etc/dpdk-pktgen-settings.sh
export DPDK_PKTGEN_DIR=$srcdir/$PKTGEN
export DPDK_PKTGEN_EXEC=$srcdir/$PKTGEN/app/app/$RTE_TARGET/pktgen
EOF

exit 0
