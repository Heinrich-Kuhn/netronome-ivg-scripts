#!/bin/bash

cat << 'EOF' > /etc/netronome.conf
SDN_VIRTIORELAY_ENABLE=n
SDN_FIREWALL=n
EOF

echo "NEW configuration"
cat /etc/netronome.conf

ovs-ctl stop
ovs-ctl start
ovs-ctl status

exit 0
