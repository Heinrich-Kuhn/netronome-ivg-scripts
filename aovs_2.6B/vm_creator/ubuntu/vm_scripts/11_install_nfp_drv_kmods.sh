#!/bin/bash

function check_status () {
  rc="$?" ; errmsg="$1"
  if [ "$rc" != "0" ]; then
    echo "ERROR($0): $errmsg"
    exit -1
  fi
}

logdir="/var/log/install"
mkdir -p $logdir
mkdir -p /opt/src

url="https://github.com/Netronome/nfp-drv-kmods"
drvdir="/opt/src/nfp-drv-kmods"
if [ ! -d $drvdir ]; then
    git clone $url $drvdir \
        || exit -1
fi

cd $drvdir
    check_status "missing directory $drvdir"

make | tee $logdir/make-nfp-drv-kmods.log
    check_status "failed to build nfp-drv-kmods"

make install | tee $logdir/make-install-nfp-drv-kmods.log \
    check_status "failed to install nfp-drv-kmods"

make clean

depmod --all
    check_status "failed to execute 'depmod'"

exit 0
