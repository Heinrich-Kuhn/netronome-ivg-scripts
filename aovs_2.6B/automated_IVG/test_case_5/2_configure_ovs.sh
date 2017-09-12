#!/bin/bash

XVIO_CPU_COUNT=$1

echo "CURRENT configuration"
cat /etc/netronome.conf

card_node=$(cat /sys/bus/pci/drivers/nfp/0*/numa_node | head -n1 | cut -d " " -f1)
nfp_cpu_list=$(lscpu -a -p | awk -F',' -v var="$card_node" '$4 == var {printf "%s%s",sep,$1; sep=" "} END{print ""}')
xvio_cpus_list=()
nfp_cpu_list=( $nfp_cpu_list )

for counter in $(seq 0 $((XVIO_CPU_COUNT-1)))
  do
	xvio_cpus_list+=( "${nfp_cpu_list[$counter+1]}" )
done

for counter in $(seq 0 $((XVIO_CPU_COUNT-1)))
  do
	nfp_cpu_list=( "${nfp_cpu_list[@]:1}" )
done

xvio_cpus_string=$(IFS=',';echo "${xvio_cpus_list[*]}";IFS=$' \t\n')

cat > /etc/netronome.conf << EOF
SDN_VIRTIORELAY_ENABLE=y
SDN_VIRTIORELAY_PARAM="--cpus=$xvio_cpus_string --enable-tso --enable-mrgbuf --vhost-username=libvirt-qemu --vhost-groupname=kvm --huge-dir=/mnt/huge --ovsdb-sock=/var/run/openvswitch/db.sock"
SDN_FIREWALL=n
EOF

echo "NEW configuration"
cat /etc/netronome.conf

ovs-ctl status
ovs-ctl stop
ovs-ctl start
ovs-ctl status


