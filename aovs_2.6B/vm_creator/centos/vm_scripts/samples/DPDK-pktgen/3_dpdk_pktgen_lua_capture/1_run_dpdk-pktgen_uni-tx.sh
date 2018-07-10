#!/bin/bash

VXLAN=$1

. /etc/dpdk-pktgen-settings.sh || exit -1

if [ ! -d "$DPDK_PKTGEN_DIR" ] || [ ! -x "$DPDK_PKTGEN_EXEC" ]; then
    echo "ERROR: dpdk-pktgen is not properly installed"
    exit -1
fi

ealargs=()
appargs=()

script_dir="$(dirname $(readlink -f $0))"

CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)

# Check for virtIO-relay interfaces on bus 1, otherwise, it will be SR-IOV interfaces
lspci | grep 01:
if [ $? == 1 ]; then
    NETRONOME_VF_LIST=$(lspci -d 19ee: | awk '{print $1}')
else
    NETRONOME_VF_LIST=$(lspci | grep 01: | awk '{print $1}')
fi

# whitelist
whitelist=""
for netronome_vf in ${NETRONOME_VF_LIST[@]}; do
    ealargs+=( "-w" "$netronome_vf" )
done

# cpumapping
cpu_counter=1
port_counter=0
for netronome_vf in ${NETRONOME_VF_LIST[@]}; do
    appargs+=( "-m" "${cpu_counter}.${port_counter}" )
    cpu_counter=$(( ( cpu_counter + 1 ) % CPU_COUNT ))
    port_counter=$((port_counter + 1))
done

case "$VXLAN" in
    "n") appargs+=( "-f" "$script_dir/unidirectional_transmitter.lua" ) ;;
    "y") appargs+=( "-f" "$script_dir/unidirectional_transmitter_vxlan.lua" ) ;;
    *) echo "ERROR: script expects an argument (y|n)" ; exit -1 ;;
esac

ealargs+=( "--file-prefix" "dpdk0_" )
ealargs+=( "--log-level" "7" )
ealargs+=( "--proc-type" "auto" )
ealargs+=( "-n" "4" )
ealargs+=( "--socket-mem" "1440" )
ealargs+=( "-l" "0-$((CPU_COUNT - 1))" )

appargs+=( "-N" )

mkdir -p /var/log/ivg
echo "$DPDK_PKTGEN_EXEC ${ealargs[@]} -- ${appargs[@]}" \
    >> /var/log/ivg/pktgen-command.log

cd $DPDK_PKTGEN_DIR

$DPDK_PKTGEN_EXEC ${ealargs[@]} -- ${appargs[@]} \
    || exit -1

reset

exit 0
