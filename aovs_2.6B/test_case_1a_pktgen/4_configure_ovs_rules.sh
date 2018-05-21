#!/bin/bash

BRIDGE=br0

ovs-ofctl del-flows $BRIDGE
ovs-ofctl add-flow $BRIDGE actions=NORMAL
