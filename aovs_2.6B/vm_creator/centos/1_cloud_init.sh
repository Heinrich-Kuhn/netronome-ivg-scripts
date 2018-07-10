#!/bin/bash

#Cloud init script

VM_NAME="centos_backing"

#Generate ssh keypair, if no existing keypair is found, a new keypair will be created
if [ ! -f ~/.ssh/id_rsa ]; then
      echo -e "Generating SSH keypair..."
      ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
fi

if [ "$IVG_HTTP_PROXY" == "" ]; then
   utils="/root/IVG_folder/helper_scripts"
   IVG_HTTP_PROXY=$($utils/get-server-proxy-settings.sh)
fi

if [ "$IVG_HTTP_PROXY" != "" ]; then
    IVG_PROXY_EXPORT="export http_proxy=$IVG_HTTP_PROXY"
fi

SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

#Generating cloud-config file
cd /var/lib/libvirt/images/
cat > user_data << EOL
#cloud-config
debug: True
ssh_pwauth: True
disable_root: false
chpasswd:
  list: |
    root:changeme
  expire: false

write_files:
   -   content: ${SSH_KEY}
       path: /root/.ssh/authorized_keys
   -   content: "Netronome performance VM"
       path: /root/README 

runcmd:
- mkdir -p /root/.ssh
- sed -i -e '/^Port/s/^.*$/Port 22/' /etc/ssh/sshd_config
- sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
- sed -i -e '$aAllowUsers root' /etc/ssh/sshd_config
- service ssh restart
- yum -y remove cloud-init
- poweroff
EOL

# Check for package install
if [ -f /etc/redhat-release ]; then
    rpm -qa cloud-image-utils | grep -q cloud-utils
    if [ $? -ne 0 ]; then
        yum install cloud-utils -y
    fi
fi

if [ -f /etc/lsb-release ]; then
    dpkg -l cloud-image-utils | grep -q cloud-image-utils
    if [ $? -ne 0 ]; then
        apt-get install cloud-image-utils -y
    fi
fi

#Generate tmp cloud-init data
cloud-localds user_data_1.img user_data \
    || exit -1

exit 0
