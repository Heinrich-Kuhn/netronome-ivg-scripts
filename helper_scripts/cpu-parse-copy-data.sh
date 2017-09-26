#!/bin/bash

file_name=$1

kill -9 $(pgrep mpstat) || true

echo "time,$(sed '3q;d' /tmp/${file_name} | tr -s ' ' ',' | cut -d ',' -f3-)" > /root/IVG_folder/${file_name}.csv
tail -n +4 /tmp/${file_name} | tr -s ' ' ',' | cut -d ',' -f1,3- >> /root/IVG_folder/${file_name}.csv
exit 0
