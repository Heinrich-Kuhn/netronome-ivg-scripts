#!/bin/bash

# Synchronize package index files
yum -y update --exclude=kernel*

# Install required packages
yum -y install make gcc gcc-c++ libxml2 glibc kernel-devel-$(uname -r) libpcap-devel python wget
