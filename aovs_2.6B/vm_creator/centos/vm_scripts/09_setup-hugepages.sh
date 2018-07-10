#!/bin/bash

echo "vm.nr_hugepages=512" \
  > $vmfs/etc/sysctl.d/hugepages.conf

exit 0
