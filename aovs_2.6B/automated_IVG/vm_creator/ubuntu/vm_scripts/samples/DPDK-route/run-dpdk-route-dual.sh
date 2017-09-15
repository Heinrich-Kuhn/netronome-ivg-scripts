#!/bin/bash

eal=()

eal+=("-n" "2" )
eal+=( "--socket-mem" "256" )
eal+=( "--proc-type" "auto" )

arg=()
# Number of Queues per core
arg+=( "-q" "2" )

arg0=()
arg1=()

arg0+=( "-p" "0x01" )
arg1+=( "-p" "0x02" )

# Configure the two ports with IP addresses. To make sure that no packets
# get routed between the ports, place them in different routing domains.
arg0+=( "--iface-addr" "0:10#10.0.10.1/24" )
arg1+=( "--iface-addr" "1:11#10.0.11.1/24" )

arg0+=( "--route" "10#10.0.10.2/32@10.0.10.9" )
arg1+=( "--route" "11#10.0.11.2/32@10.0.11.9" )

/usr/local/bin/route ${eal[@]} --file-prefix rt0 -c 0x02 \
    -- ${arg[@]} ${arg0[@]} > ~/rt0.log 2>&1 &

/usr/local/bin/route ${eal[@]} --file-prefix rt1 -c 0x04 \
    -- ${arg[@]} ${arg1[@]} > ~/rt1.log 2>&1 &
