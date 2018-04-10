#!/bin/bash

function usage () {
cat <<EndOfText
$(basename $0): Tool to shutdown and undefine VMs.
    --help              - Print usage
    --name <VM name>    - Specify VM to delete
    --all               - Delete all VMs
    --filter <VM start name>
                        - Delete all VMs with matching name
    --shutdown          - Just shutdown running VMs
EndOfText
}

actions="shutdown destroy undefine"
filter=""

for arg in $@ ; do
    if [ "$param" == "" ]; then
        case $arg in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "-a"|"--all")       filter="\S+" ;;
        "-n"|"--name")      param="name" ;;
        "-f"|"--filter")    param="filter";;
        "--shutdown")       actions="shutdown" ;;
        *)  echo "ERROR($0): unknown argument $arg"
            exit -1
        esac
    else
        case "$param" in
        "name")     filter="${arg}" ;;
        "filter")   filter="${arg}\S*" ;;
        esac
        param=""
    fi
done

if [ "$filter" == "" ]; then
    echo "ERROR($0): please specify a VM name of filter"
    exit -1
fi

for mode in $actions ; do

    case $mode in
        shutdown)
            states="--state-running"
            timeout=20
            ;;
        destroy)
            states="--state-running --state-paused"
            timeout=10
            ;;
        undefine)
            states="--all"
            timeout=20
            ;;
    esac

    vmlist=( $(virsh list $states \
        | tail -n +3 \
        | awk '{print $2}' \
        | grep -E '^'"$filter"'$' ) )

    for vmname in ${vmlist[@]} ; do
        echo " - $mode VM $vmname"
        virsh $mode $vmname > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "WARNING($0): failed to $mode $vmname"
        fi
    done

    while [ ${#vmlist[@]} -gt 0 ]; do

        if [ $(( timeout-- )) -eq 0 ]; then
            if [ "$mode" == "shutdown" ]; then
                echo "WARNING($0): the following VM(s) failed to shutdown"
                echo "  ${vmlist[@]}"
                break
            fi
            echo "ERROR($0): the following VM(s) failed to $mode"
            echo "  ${vmlist[@]}"
            exit -1
        fi

        sleep 1

        vmlist=( $(virsh list $states \
            | tail -n +3 \
            | awk '{print $2}' \
            | grep -E '^'"$filter"'$' ) )
    done

done

exit 0
