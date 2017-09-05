#!/bin/bash

rpm -Uvh http://repo.iotti.biz/CentOS/5/noarch/lux-release-0-1.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-LUX
yum -y install netperf
