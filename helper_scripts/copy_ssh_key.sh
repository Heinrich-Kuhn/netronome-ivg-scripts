#!/bin/bash

tmux select-pane -t 0
    if [ ! -f ~/.ssh/netronome_key ]; then
        ssh-keygen -t rsa -f ~/.ssh/netronome_key -q -P ""
        ssh-add ~/.ssh/netronome_key
    fi
    ssh-copy-id -i ~/.ssh/netronome_key.pub root@$1
    ssh-copy-id -i ~/.ssh/netronome_key.pub root@$2

echo "Public key has been copied"
