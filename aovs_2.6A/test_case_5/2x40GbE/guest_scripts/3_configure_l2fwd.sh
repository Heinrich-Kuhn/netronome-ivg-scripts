#!/bin/bash


#run l2fwd
./dpdk-l2fwd  -c 0x03 -n 4 --socket-mem 1024 --proc-type auto -- -p 0x3 --no-mac-updating
