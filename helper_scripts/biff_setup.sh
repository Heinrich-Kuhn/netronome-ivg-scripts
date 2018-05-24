#!/bin/bash
#  echo "export DISPLAY=localhost:0.0" >> ~/.bashrc
#  . ~/.bashrc

#Check if TMUX is installed

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    apt-get -y install default-jdk
    apt-get -y install default-jre
    apt-get -y install openjfx
    apt-get -y install x11-apps
fi

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
    yum -y install default-jdk
    yum -y install default-jre
    yum -y install openjfx
    yum -y install x11-apps
fi

RX_DUT_IP=$1

script_dir="$(dirname $(readlink -f $0))"
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"

BIFF_dir=$(find /root -name "BIFF")
read -p "Wait"
# Copy BIFF to DUT
#scp -i ~/.ssh/netronome_key -r $BIFF_dir root@$RX_DUT_IP:/root/IVG_folder
MY_IP=$(ip route get $RX_DUT_IP | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v $RX_DUT_IP)
echo "MY IP: $MY_IP"
read -p "Wait"
# Launch Oscar on RX_DUT
echo "sed -i 's#TargetConnection IP=".*" PORT=".*"#TargetConnection IP=\"'$MY_IP'\" PORT=\"50123\"#g'"
ssh -i ~/.ssh/netronome_key root@$RX_DUT_IP 'sed -i "s@TargetConnection IP=\".*\" PORT=\".*\"@TargetConnection IP=\"'$MY_IP'\" PORT=\"50123\"@g" /root/IVG_folder/BIFF/Board-Instrumentation-Framework/Oscar/OscarConfig.xml'
ssh -i ~/.ssh/netronome_key root@$RX_DUT_IP 'cd /root/IVG_folder/BIFF/Board-Instrumentation-Framework/Oscar/; python3 Oscar.py '& > /dev/null 2>&1
read -p "Wait"

# Launch Minions on RX_DUT
ssh -i ~/.ssh/netronome_key root@$RX_DUT_IP 'sed -i "s@<Alias stingray=.*>@<Alias stingray=\"'$RX_DUT_IP'\/>"@g" /root/IVG_folder/BIFF/Board-Instrumentation-Framework/Minion/pktgenCapture.xml'
ssh -i ~/.ssh/netronome_key root@$RX_DUT_IP 'cd /root/IVG_folder/BIFF/Board-Instrumentation-Framework/Minion/; python3 Minion.py -i pktgenCapture.xml '& > /dev/null 2>&1
read -p "Wait"


#Edit Marvin
sed -i "s@<Network IP=\".*\" PORT=\".*\"@<Network IP=\"$MY_IP\" PORT=\"50123\"@g"  /root/BIFF/Board-Instrumentation-Framework/Marvin/build/libs/Application.xml
#Launch Marvin on Local
cd /root/BIFF/Board-Instrumentation-Framework/Marvin/build/libs
java -jar BIFF.Marvin.jar &

exit 0
