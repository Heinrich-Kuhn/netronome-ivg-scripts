#!/bin/bash

eal=()

# Use the second core
eal+=("-c" "0x02" )
eal+=("-n" "2" )
eal+=( "--socket-mem" "256" )
eal+=( "--proc-type" "auto" )

arg=()
# Port Bitmask (in hexadecimal)
arg+=( "-p" "0x03" )
# Number of Queues per core
arg+=( "-q" "2" )

# Configure the two ports with IP addresses. To make sure that no packets
# get routed between the ports, place them in different routing domains.
arg+=( "--iface-addr" "0:10#10.0.10.1/24" )
arg+=( "--iface-addr" "1:11#10.0.11.1/24" )

arg+=( "--route" "10#10.0.10.2/32@10.0.10.9" )
arg+=( "--route" "11#10.0.11.2/32@10.0.11.9" )

exec /usr/local/bin/route ${eal[@]} -- ${arg[@]}
