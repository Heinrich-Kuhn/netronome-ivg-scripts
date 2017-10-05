#!/bin/bash

#Cloud init script

script_dir="$(dirname $(readlink -f $0))"
VM_NAME=ubuntu_backing

GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'


#Generate ssh keypair, if no existing keypair is found, a new keypair will be created
if [ ! -f ~/.ssh/id_rsa ]; then
      echo -e "${GREEN}Generating SSH keypair...${NC}"
      ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
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
- mkdir /root/.ssh/
- sed -i -e '/^Port/s/^.*$/Port 22/' /etc/ssh/sshd_config
- sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
- sed -i -e '$aAllowUsers root' /etc/ssh/sshd_config
- service ssh restart
- yum -y remove cloud-init
- poweroff
EOL
  
# Check for package install
if [ -f /etc/redhat-release ]; then
  rpm -qa cloud-image-utils | grep -q cloud-utils || yum install cloud-utils -y
fi

if [ -f /etc/lsb-release ]; then
  dpkg -l cloud-image-utils | grep -q cloud-image-utils || apt-get install cloud-image-utils -y
fi

#Generate tmp cloud-init data
cloud-localds user_data_1.img user_data
