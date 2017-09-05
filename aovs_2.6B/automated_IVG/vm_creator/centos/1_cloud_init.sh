#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"
VM_NAME=centos_backing

cd /var/lib/libvirt/images/

#Generate ssh keypair, if no existing keypair is found, a new keypair will be created
if [ ! -f ~/.ssh/id_rsa ]; then
      echo -e "${GREEN}Generating SSH keypair...${NC}"
      ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
fi

SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

cat > user_data << EOL
#cloud-config
debug: True
ssh_pwauth: True
disable_root: false
ssh_authorized_keys:
  - $SSH_KEY
chpasswd:
  list: |
    root:netronome
  expire: false
runcmd:
- sed -i -e '/^Port/s/^.*$/Port 22/' /etc/ssh/sshd_config
- sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
- sed -i -e '$aAllowUsers root' /etc/ssh/sshd_config
- service ssh restart
- yum -y remove cloud-init
- poweroff
EOL

# Check for package install

if [ -f /etc/redhat-release ]; then
  rpm -qa cloud-image-utils | grep -q cloud-utils || apt-get install cloud-utils -y
fi

if [ -f /etc/lsb-release ]; then
  dpkg -l cloud-image-utils | grep -q cloud-image-utils || yum install cloud-image-utils -y
fi



# Create image
cloud-localds user_data_1.img user_data

