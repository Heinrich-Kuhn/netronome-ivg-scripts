#!/bin/bash

cat << 'EOF' > /etc/netronome.conf
SDN_VIRTIORELAY_ENABLE=n
SDN_FIREWALL=n
EOF

ovs-ctl stop   || exit -1
ovs-ctl start  || exit -1
ovs-ctl status || exit -1

exit 0
