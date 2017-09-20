#!/bin/bash



virsh list | while read x; do

        status="$(echo $x | cut -d ' ' -f3)"

        echo $status

        if [[ $status == "running" ]]

        then

                device="$(echo $x | cut -d ' ' -f2)"

                virsh shutdown $device
                virsh undefine $device

        fi

done
