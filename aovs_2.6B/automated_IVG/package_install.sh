#!/bin/bash
#package_install.sh

#Get Ubuntu Version
UBUNTU_VERSION=$(lsb_release -a 2>/dev/null | grep Codename: | awk '{print $2}')


#Checking AOVS version
DATA_DIR=/opt/netronome/etc
for SCRIPT in ns_sdn_revision.sh ns_sdn_version.sh ns_sdn_install_type.sh; do
  if [ -f $DATA_DIR/$SCRIPT ]; then
    . $DATA_DIR/$SCRIPT
  fi
done

#Check if AOVS is installed, uninstall if present
if [ -z ${NS_SDN_REVISION+x} ]; then
   echo "Agilio-OVS is not installed"
   
else
   NS_SDN_REVISION=$(echo $NS_SDN_REVISION | cut -f1 -d":")
   #echo "Agilio-OVS $NS_SDN_VERSION Revision $NS_SDN_REVISION is installed"
   #echo "Uninstalling Agilio-OVS"
   /opt/netronome/bin/agilio-ovs-uninstall.sh -y
   
   #Check if uninstall script exited cleanly
   if [ $? == 1 ]; then
      exit 1
   fi
fi

#Check if any agilio .tar files are in the folder
cd /root/IVG_folder
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
   dpkg -i *.deb || exit -1
   echo
   echo
   echo "Flashing NFP firmware, please wait..."
   sleep 10
   /opt/netronome/bin/nfp-update-flash.sh
fi

exit 0

