#!/bin/bash

ls agilio-ovs-2.6.B-r* 2>/dev/null

if [ $? == 2 ]; then
   echo "Could not find Agilio-OVS .tar.gz file in folder"
   echo "Please copy the Agilio-OVS .tar.gz file into the same folder as this script"
   exit 1
else
   
   LATEST_AOVS=$(ls agilio-ovs-2.6.B-r* 2>/dev/null | grep .tar.gz | tail -n1)
   tar xf $LATEST_AOVS
   INSTALL_DIR=$(basename $LATEST_AOVS .tar.gz)
   cd $INSTALL_DIR
   
   #Check ubuntu version
   if [ $UBUNTU_VERSION == "trusty" ]; then
      cd trusty
   else
      cd xenial
   fi
   dpkg -i nfp-bsp-6000-b0_2017.09.12.1114-1_amd64.deb || exit -1
   dpkg -i ns-agilio-core-nic_1.1-360_all.deb || exit -1
   echo
   echo
   echo "CoreNIC has been installed!"
fi

exit 0
