#!/bin/bash
default_kovs_version='2.6.1'
source_flag=0

function print_usage {
    echo "Script which installing Kovs"
    echo "Usage: "
    echo "-v           --version               Kovs version to install(Default:"$default_kovs_version")"
    echo "-s <path>    --source  <path>        Path to extracted kovs source"
    echo "-h           --help                  Prints this message and exits"
}

while [[ $# -gt 0 ]]
do
    argument="$1"
    case $argument in
        # Help
        -h|--help) print_usage; exit 1;;
        # Version
        -v|--version) kovs_version="$2"; shift 2;;
        # Version
        -s|--source) source_flag=1;source_path="$2"; shift 2;;
        -*) echo "Unkown argument: \"$argument\""; print_usage; exit 1;;
    esac
done

if [ -z "$kovs_version" ]
then
    kovs_version=$default_kovs_version
fi

if [ $source_flag -ne 1 ]
then
    #Remove previous kovs
    rm -rf /usr/local/src/kovs
    # Clone KOVS
    mkdir -p /usr/local/src/kovs
    cd /usr/local/src/kovs
    git clone https://github.com/openvswitch/ovs.git
    cd ovs
    git checkout v$kovs_version

    #Configure KOVS
    ./boot.sh
    ./configure --with-linux=/lib/modules/$(uname -r)/build

    # Make KOVS
    make
    # Unit Tests
    # make check

    # Install KOVS
    make install
    make modules_install
    ovs-ctl stop
    /sbin/modprobe openvswitch
    mkdir -p /usr/local/etc/openvswitch
    ovsdb-tool create /usr/local/etc/openvswitch/conf.db \
    vswitchd/vswitch.ovsschema
    mkdir -p /usr/local/var/run/openvswitch
    ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
        --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
        --private-key=db:Open_vSwitch,SSL,private_key \
        --certificate=db:Open_vSwitch,SSL,certificate \
        --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
        --pidfile --detach --log-file
    ovs-vsctl --no-wait init
    ovs-vswitchd --pidfile --detach --log-file

    # Add to path and start KOVS
    rm -f /usr/local/bin/ovs-lib /usr/local/bin/ovs-ctl
    ln -s /usr/local/share/openvswitch/scripts/ovs-ctl /usr/local/bin/ovs-ctl
    ln -s /usr/local/share/openvswitch/scripts/ovs-lib /usr/local/bin/ovs-lib
    ovs-ctl start
else
    cd $source_path/
    echo 'BOOT'
    ./boot.sh
    echo 'CONFIGURE'
    ./configure --with-linux=/lib/modules/$(uname -r)/build
    echo 'MAKE'
    make
    make install

    insmod datapath/linux/openvswitch.ko
    touch /usr/local/etc/ovs-vswitchd.conf
    mkdir -p /usr/local/etc/openvswitch
    ovsdb-tool create /usr/local/etc/openvswitch/conf.db

    ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
        --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
        --private-key=db:Open_vSwitch,SSL,private_key \
        --certificate=db:Open_vSwitch,SSL,certificate \
        --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
        --pidfile --detach --log-file

    ovs-vsctl --no-wait init
    ovs-vswitchd --pidfile --detach --log-file

    rm -f /usr/local/bin/ovs-lib /usr/local/bin/ovs-ctl
    ln -s /usr/local/share/openvswitch/scripts/ovs-ctl /usr/local/bin/ovs-ctl
    ln -s /usr/local/share/openvswitch/scripts/ovs-lib /usr/local/bin/ovs-lib
    ovs-ctl start
fi

exit 0
