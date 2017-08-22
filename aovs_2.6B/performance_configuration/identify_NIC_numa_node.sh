#!/bin/bash
#identify_NIC_numa_node.sh

if [ ! -d /sys/bus/pci/drivers/nfp ]; then
  echo "ERROR: missing /sys/bus/pci/drivers/nfp"
  exit -1
fi

for card in /sys/bus/pci/drivers/nfp/0*; do
    address=`basename $card`
    echo "Agilio address: $address"
    echo -n "NUMA node: "; cat $card/numa_node
    echo -n "Local CPUs: "; cat $card/local_cpulist
done

exit 0
