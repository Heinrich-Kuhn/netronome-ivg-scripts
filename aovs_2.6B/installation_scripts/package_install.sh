#!/bin/bash
#package_install.sh

dpkg -i *.deb \
  || exit -1

exit 0
