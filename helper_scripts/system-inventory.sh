#!/bin/bash

########################################################
tmpdir=$(mktemp --directory)
capname="capture-$(date +'%Y-%m-%d-%H%M')"
capdir="$tmpdir/$capname"

mkdir -p $capdir

########################################################
# Copy system files

list=()
list+=( "/etc/hostname" )
list+=( "/etc/os-release" )
list+=( "/etc/hosts" )
list+=( "/etc/fstab" )
list+=( "/etc/netronome.conf" )
list+=( "/etc/timezone" )
list+=( "/etc/grub" )
list+=( "/etc/irqbalance" )
list+=( "/etc/libvirt-bin" )
list+=( "/etc/rc.local" )

list+=( "/boot/grub/grub.cfg" )
list+=( "/boot/grub2/grub.cfg" )
list+=( "/boot/grub/grubenv" )
list+=( "/boot/grub2/grubenv" )

list+=( "/etc/default/irqbalance" )

list+=( "/etc/apparmor.d/abstractions/libvirt-qemu" )

list+=( "/proc/cmdline" )
list+=( "/proc/interrupts" )
list+=( "/proc/meminfo" )
list+=( "/proc/mounts" )
list+=( "/proc/uptime" )
list+=( "/proc/version" )
list+=( "/proc/vmstat" )
list+=( "/proc/net/dev" )

list+=( "/sys/module/nfp_offloads/control/rh_entries" )

list+=( "/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages" )

########################################################
if [ -d /sys/bus/pci/drivers/nfp ]; then
    nfplist=$(find /sys/bus/pci/drivers/nfp -type l -name '*:*:*.*')
    for nfpdir in $nfplist ; do
        list+=( "$nfpdir/numa_node" )
        list+=( "$nfpdir/irq" )
    done
fi

########################################################
for fname in ${list[@]} ; do
    if [ -e $fname ]; then
        /bin/cp -R --parents $fname \
            --target-directory $capdir
    else
        echo "Missing $fname" >> $capdir/missing-files.txt
    fi
done

########################################################
function run () {
    local cmd="$1"
    local args="$2"
    local fname="$3"
    if [ -x $cmd ]; then
        $cmd $args > $capdir/$fname 2>&1
    else
        tool=$(which $cmd 2> /dev/null)
        if [ -x "$tool" ]; then
            $tool $args > $capdir/$fname 2>&1
        else
            echo "Missing $cmd" >> $capdir/missing-tools.txt
        fi
    fi
}

########################################################

run "uname" "-r"                "kernel-version.txt"
run "uname" "-a"                "uname-all.txt"
run "lscpu" ""                  "lscpu.txt"
run "lspci" ""                  "lspci.txt"
run "lspci" "-vvv"              "lspci-vvv.txt"
run "dmesg" ""                  "dmesg.txt"
run "yum" "list"                "yum-list.txt"
run "dpkg" "--get-selections"   "dpkg-pkg-list.txt"
run "ifconfig" ""               "ifconfig.txt"
run "arp" "-n"                  "arp-n.txt"
run "route" "-n"                "route-n.txt"
run "netstat" "-s"              "netstat-s.txt"
run "lsmod" ""                  "lsmod.txt"
run "ps" "aux"                  "ps-aux.txt"
run "dmidecode" ""              "dmidecode.txt"
run "lshw" ""                   "lshw.txt"
run "printenv" ""               "printenv.txt"

run "virsh" "--version"         "virsh-version.txt"
run "kvm" "--version"           "kvm-version.txt"
run "/usr/libexec/qemu-kvm" "--version" "qemu-kvm-version.txt"

run "getenforce" "" "selinux-getenforce.txt"

run "/opt/netronome/bin/ovs-ctl" "version" "ovs-version.txt"
run "/opt/netronome/bin/ovs-ctl" "status" "ovs-status.txt"
run "/opt/netronome/bin/nfp-hwinfo" "" "nfp-hwinfo.txt"
run "/opt/netronome/bin/nfp-media" "" "nfp-media.txt"
run "/opt/netronome/bin/nfp-programmables" "" "nfp-programmables.txt"
run "/opt/netronome/bin/nfp-arm" "-D" "nfp-arm-D.txt"
run "/opt/netronome/bin/nfp-phymod" "" "nfp-phymod.txt"
run "/opt/netronome/bin/nfp-res" "-L" "nfp-res-locks.txt"

run "ovs-dpctl" "dump-flows -m" "ovs-dpctl-flows.txt"
run "ovs-ctl" "status troubleshoot -C" "ovs-ctl-status-troubleshoot.txt"

run "nfp" "-m mac show port info 0 0" "nfp-mac-0-0-first.txt"
run "nfp" "-m mac show port info 0 4" "nfp-mac-0-4-first.txt"
run "nfp" "-m mac show port info 0 0" "nfp-mac-0-0-second.txt"
run "nfp" "-m mac show port info 0 4" "nfp-mac-0-4-second.txt"

run "ovs-appctl" "bond/list" "bond-list.txt"

run "ovs-vsctl" "show" "ovs-vsctl-show.txt"

########################################################

nscnt=$(lspci -d 19ee: | wc -l)
if [ $nscnt -lt 1 ]; then
    echo "ERROR: card missing" > $capdir/pci-patch.txt
else
    check=$(setpci -d 19ee:4000 0xFFC.L | sed '2,$d')
    if [ "$check" != "ffffffff" ]; then
        echo "WARNING: patch MISSING" > $capdir/pci-patch.txt
    else
        echo "Patch Applied" > $capdir/pci-patch.txt
    fi
fi

########################################################
for pid in $(pgrep virtiorelayd) ; do
    cat /proc/$pid/cmdline \
        | tr '\0' ' ' \
        > $capdir/virtiorelayd-$pid-cmdline.txt
done

########################################################
tool="/opt/netronome/bin/virtio_relay_stats"
if [ -x $tool ] && [ "$(pgrep virtiorelayd)" != "" ]; then
    $tool > $capdir/nfp-virtio-stats.txt
fi

########################################################
virsh="$(which virsh)"
if [ "$virsh" != "" ]; then
    for vmname in $(virsh list --all --name) ; do
        vmdir="$capdir/virsh/vms/$vmname"
        mkdir -p $vmdir
        virsh dumpxml $vmname > $vmdir/config.xml
        virsh dominfo $vmname > $vmdir/dominfo.txt
        virsh vcpuinfo $vmname > $vmdir/vcpuinfo.txt
    done
    for netname in $(virsh net-list --name) ; do
        netdir="$capdir/virsh/net/$netname"
        mkdir -p $netdir
        virsh net-dumpxml $netname > $netdir/config.xml
        virsh net-dhcp-leases $netname > $netdir/leases.txt
    done
fi

########################################################
mkdir -p $capdir/log
loglist=()
loglist+=( "syslog" )
loglist+=( "messages" )
for logfile in $loglist ; do
    if [ -f "/var/log/$logfile" ]; then
        cat /var/log/$logfile \
            | tail -1000 \
            > $capdir/log/$logfile-tail.txt
        cat /var/log/$logfile \
            | grep -E '(nfp|kvm|virtiorelayd)' \
            | tail -1000 \
            > $capdir/log/$logfile-filtered-tail.txt
    fi
done

########################################################
if [ -x /sbin/ethtool ]; then
    iflist=$(cat /proc/net/dev \
        | sed -rn 's/^\s*(\S+):.*$/\1/p')
    ifdir="$capdir/ethtool"
    mkdir -p $ifdir/info $ifdir/features $ifdir/stats
    for ifname in $iflist ; do
        ethtool -i $ifname > $ifdir/info/$ifname.txt 2>&1
        ethtool -k $ifname > $ifdir/features/$ifname.txt 2>&1
        ethtool -S $ifname > $ifdir/stats/$ifname.txt 2>&1
    done
fi

########################################################
# Capture Link-Aggregation (bonding) Status

listfile="$capdir/bond-list.txt"
if [ -f $listfile ]; then
    mkdir -p $capdir/bond
    bondlist=$(cat $listfile \
        | tail -n +2 \
        | cut -f 1)
    for bondname in $bondlist ; do
        ovs-appctl bond/show $bondname 2>&1 \
            > $capdir/bond/$bondname-bond.txt
        ovs-appctl lacp/show $bondname 2>&1 \
            > $capdir/bond/$bondname-lacp.txt
    done
fi

########################################################
if [ -x $(which ovs-vsctl) ]; then
    for brname in $(ovs-vsctl list-br) ; do
        brdir="$capdir/ovs/$brname"
        mkdir -p $brdir
        ovs-vsctl list-ports  $brname \
            > $brdir/vsctl-ports.txt
        ovs-ofctl dump-ports -O OpenFlow13 $brname \
            > $brdir/ofctl-ports.txt
        ovs-ofctl dump-ports-desc -O OpenFlow13 $brname \
            > $brdir/ofctl-ports-desc.txt
        ovs-ofctl dump-flows -O OpenFlow13 $brname \
            > $brdir/ofctl-flows.txt
        ovs-appctl fdb/show $brname \
            > $brdir/ofctl-fdb-show.txt
    done
fi
        
########################################################
# Copy capture script

/bin/cp $0 --target-directory $capdir

########################################################

tar cz -C $tmpdir -f $HOME/$capname.tgz $capname

/bin/rm -rf $tmpdir

echo "System Inventory Capture file: $HOME/$capname.tgz"

########################################################
exit 0
