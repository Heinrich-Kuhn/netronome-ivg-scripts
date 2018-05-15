#!/bin/bash

if [ "$http_proxy" != "" ]; then
    echo "$http_proxy"
    exit 0
fi

. /etc/os-release

case "$ID_LIKE" in
  "debian")
    # First, search the package management for a proxy setting
    flist=()
    if [ -f /etc/apt/apt.conf ]; then
        flist+=( /etc/apt/apt.conf )
    fi
    if [ -d /etc/apt/apt.conf.d ]; then
        flist+=( /etc/apt/apt.conf.d/* )
    fi
    if [ ${#flist[@]} -gt 0 ]; then
        proxy=$(cat ${flist[@]} \
            | sed -rn 's/^\s*Acquire::http::proxy\s(.*)$/\1/p' \
            | sed -rn 's#^.*(http://[0-9.:]+).*$#\1#p' \
            | tail -1)
        if [ "$proxy" != "" ]; then
            echo "$proxy"
            exit 0
        fi
    fi
    ;;
  "fedora")
    if [ -f /etc/yum.conf ]; then
        proxy=$(cat /etc/yum.conf \
            | sed -rn 's/^\s*proxy=(.*)$/\1/p' \
            | tail -1)
        if [ "$proxy" != "" ]; then
            echo "$proxy"
            exit 0
        fi
    fi
    ;;
  *)
esac

# Check Server for Proxy Configuration
proxy=$(cat /etc/profile /etc/profile.d/* \
    | sed -rn 's/^\s*export\s+http_proxy=(\S+)\s*.*$/\1/p' \
    | tail -1)

if [ "$proxy" != "" ]; then
    echo "$proxy"
    exit 0
fi

# No Proxy Settings found
exit 0
