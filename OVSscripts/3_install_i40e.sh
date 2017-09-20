#!/bin/bash
# Usefull links
# https://docs.oracle.com/cd/E59668_01/html/E59667/z40001c91006831.html
# https://downloadcenter.intel.com/download/24411/Intel-Network-Adapter-Driver-for-PCIe-Intel-40-Gigabit-Ethernet-Network-Connections-Under-Linux-
default_f_driver_version=2.0.23
source_flag=0

function print_usage {
    echo "Script which installing fortville Firmware"
    echo "Usage: "
    echo "-v           --version               Firmware version to install(Default:"$default_f_driver_version")"
    echo "-s <path>    --source  <path>        Path to extracted firmware source"
    echo "-h           --help                  Prints this message and exits"
}

while [[ $# -gt 0 ]]
do
    argument="$1"
    case $argument in
        # Help
        -h|--help) print_usage; exit 1;;
        # Version
        -v|--version) f_driver_version="$2"; shift 2;;
        # Version
        -s|--source) source_flag=1;source_path="$2"; shift 2;;
        -*) echo "Unkown argument: \"$argument\""; print_usage; exit 1;;
    esac
done

if [ -z "$f_driver_version" ]
then
    f_driver_version=$default_f_driver_version
fi

if [ $source_flag -ne 1 ]
then
    rm -rf /usr/local/src/i40e
    wget https://sourceforge.net/projects/e1000/files/i40e%20stable/$f_driver_version/i40e-$f_driver_version.tar.gz -P /usr/local/src/i40e
    cd /usr/local/src/i40e
else
    cd $source_path
fi

rm -rf i40e-$f_driver_version
tar xf i40e-$f_driver_version.tar.gz
cd i40e-$f_driver_version/src
make install
rmmod i40e
modprobe i40e