#!/bin/bash

OUT="$(grep -n 'ENABLED="1"' /etc/default/irqbalance | cut -d: -f1)"
[ -z "$OUT" ] || sed -i "$OUT d" /etc/default/irqbalance
[ -z "$OUT" ] || sed -i "$((OUT-1)) a ENABLED=\"0\"" /etc/default/irqbalance

service irqbalance stop
