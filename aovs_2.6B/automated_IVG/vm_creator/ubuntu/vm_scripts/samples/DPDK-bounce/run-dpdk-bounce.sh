#!/bin/bash

eal=()

eal+=( "-c" "0x0e" )
eal+=( "-n" "2" )
eal+=( "--socket-mem" "1024" )
eal+=( "--proc-type" "auto" )

arg=()
# Port Bitmask (in hexadecimal)
arg+=( "-p" "0x03" )
# Number of Queues per core
arg+=( "-q" "1" )

exec /usr/local/bin/bounce ${eal[@]} -- ${arg[@]}
