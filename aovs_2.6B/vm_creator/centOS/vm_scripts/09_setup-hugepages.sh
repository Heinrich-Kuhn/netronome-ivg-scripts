#!/bin/bash

echo "vm.nr_hugepages=2048" \
  > $vmfs/etc/sysctl.d/hugepages.conf

exit 0
