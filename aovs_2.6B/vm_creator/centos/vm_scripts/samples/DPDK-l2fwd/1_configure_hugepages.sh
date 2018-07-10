#!/bin/bash

echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
