#!/bin/bash

echo "Installing Intel driver - i40e"

f_driver_version=2.0.23

rm -rf /usr/local/src/i40e
wget https://sourceforge.net/projects/e1000/files/i40e%20stable/$f_driver_version/i40e-$f_driver_version.tar.gz -P /usr/local/src/i40e
cd /usr/local/src/i40e

rm -rf i40e-$f_driver_version
tar xf i40e-$f_driver_version.tar.gz
cd i40e-$f_driver_version/src
make install
rmmod i40e

exit 0
