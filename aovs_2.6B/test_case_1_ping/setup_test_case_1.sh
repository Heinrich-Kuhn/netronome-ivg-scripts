#!/bin/bash

DEFAULT_IP="10.10.10.1"

function print_usage {
    echo "Script to setup test case 1"
    echo "Usage: "
    echo "-i <ip>       --ip <bus>                IP address to add to interface"
    echo "-h            --help                    Prints this message and exits"
}

while [[ $# -gt 0 ]]
do
    argument="$1"
    case $argument in
        # Help
        -h|--help) print_usage; exit 1;;
        -i|--ip) IP="$2"; shift 2;;
        *) echo "Unkown argument: \"$argument\""; print_usage; exit 1;;
    esac
done

if [ -z "$IP" ] ; then IP=$DEFAULT_IP ; fi

script_dir="$(dirname $(readlink -f $0))"
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"

$script_dir/1_bind_netronome_nfp_netvf_driver.sh $IP
$script_dir/2_configure_AOVS.sh
$script_dir/3_configure_bridge.sh
$script_dir/4_configure_ovs_rules.sh

echo "DONE($(basename $0))"
exit 0
