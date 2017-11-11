#!/bin/bash

brname="$1"

if [ "$PHY_IFACE_LIST" == "auto" ]; then
    # List of all physical interfaces (nfp_p)
    nfp_p_list=( $( cat /proc/net/dev \
        | sed -rn 's/^\s*(nfp_p[0-9]):.*$/\1/p' \
        ) )
    # Create list of interfaces that are 'UP'
    iflist=()
    for ifname in ${nfp_p_list[@]} ; do
        ifconfig $ifname | grep " UP " > /dev/null
        if [ "$?" == "0" ]; then
            iflist+=( "$ifname" )
        fi
    done
elif [ "$PHY_IFACE_LIST" != "" ]; then
    iflist=( $PHY_IFACE_LIST )
else
    # Default to the first physical port
    iflist=( "nfp_p0" )
fi

if [ ${#iflist[@]} -eq 0 ]; then
    echo "ERROR: no physical interfaces specified/available"
    exit -1
elif [ ${#iflist[@]} -eq 1 ]; then
    ofpidx=${PHY_IFACE_OFP_INDEX-"1"}
    # Attach a single port to the bridge
    ovs-vsctl --may-exist add-port $brname ${iflist[0]} \
        -- set interface ${iflist[0]} ofport_request=$ofpidx \
        || exit -1
else
    # Create bonded interface and attach to bridge
    bondname=${PHY_IFACE_BOND_NAME-"bond0"}
    bondmode=${PHY_IFACE_BOND_MODE-"balance-tcp"}
    lacpmode=${PHY_IFACE_BOND_LACP-"active"}
    ovs-vsctl --may-exist add-bond $brname $bondname ${iflist[@]} \
        || exit -1
    ovs-vsctl \
        -- set port $bondname bond_mode=$bondmode \
        -- set port $bondname lacp=$lacpmode \
        || exit -1
    echo -n "Wait for bond to become active "
    while : ; do
        sleep 1
        enbcnt=$(ovs-appctl bond/show $bondname \
            | grep -E '^slave nfp.*enabled' \
            | wc -l)
        [ $enbcnt -eq ${#iflist[@]} ] && break;
        echo -n "."
    done
    echo " UP"
fi

exit 0
