#!/bin/bash

if [ -z "$1" ]; then
   echo "ERROR: Number of XVIO CPU's was not passed to this scipt"
   echo "Example: ./2_configure_ovs.sh <number_of_xvio_cpu's"
   exit -1
   else
   XVIO_CPU_COUNT=$1
fi

card_node=$(cat /sys/bus/pci/drivers/nfp/0*/numa_node | head -n1 | cut -d " " -f1)
echo "CARD NODE $card_node"
nfp_cpu_list=$(lscpu -a -p | awk -F',' -v var="$card_node" '$4 == var {printf "%s%s",sep,$1; sep=" "} END{print ""}')
echo "NFP_CPU_LIST $nfp_cpu_list"
xvio_cpus_list=()
nfp_cpu_list=( $nfp_cpu_list )

for counter in $(seq 0 $((XVIO_CPU_COUNT-1)))
  do
	xvio_cpus_list+=( "${nfp_cpu_list[$counter+1]}" )
  echo $counter
done

for counter in $(seq 0 $((XVIO_CPU_COUNT-1)))
  do
	nfp_cpu_list=( "${nfp_cpu_list[@]:1}" )
done

xvio_cpus_string=$(IFS=',';echo "${xvio_cpus_list[*]}";IFS=$' \t\n')

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
  sed 's#^VIRTIOFWD_OVSDB_SOCK_PATH=.*#VIRTIOFWD_OVSDB_SOCK_PATH=/var/run/openvswitch/db.sock#g' -i /etc/default/virtioforwarder
  sed "s#^VIRTIOFWD_CPU_MASK=.*#VIRTIOFWD_CPU_MASK=$xvio_cpus_string#g" -i /etc/default/virtioforwarder
  sed 's#^VIRTIOFWD_SOCKET_OWNER=.*#VIRTIOFWD_SOCKET_OWNER=qemu#g' -i /etc/default/virtioforwarder
  sed 's#^VIRTIOFWD_SOCKET_GROUP=.*#VIRTIOFWD_SOCKET_GROUP=kvm#g' -i /etc/default/virtioforwarder
fi


grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then

  sed 's#^VIRTIOFWD_OVSDB_SOCK_PATH=.*#VIRTIOFWD_OVSDB_SOCK_PATH=/var/run/openvswitch/db.sock#g' -i /etc/default/virtioforwarder
  sed "s#^VIRTIOFWD_CPU_MASK=.*#VIRTIOFWD_CPU_MASK=$xvio_cpus_string#g" -i /etc/default/virtioforwarder
  sed 's#^VIRTIOFWD_SOCKET_OWNER=.*#VIRTIOFWD_SOCKET_OWNER=libvirt-qemu#g' -i /etc/default/virtioforwarder
  sed 's#^VIRTIOFWD_SOCKET_GROUP=.*#VIRTIOFWD_SOCKET_GROUP=kvm#g' -i /etc/default/virtioforwarder
  sed 's#^VIRTIOFWD_MRGBUF=.*#VIRTIOFWD_MRGBUF=y#g' -i /etc/default/virtioforwarder
  sed 's#^VIRTIOFWD_TSO=.*#VIRTIOFWD_TSO=y#g' -i /etc/default/virtioforwarder

fi

ovs-ctl status
ovs-ctl stop
ovs-ctl start
ovs-ctl status
