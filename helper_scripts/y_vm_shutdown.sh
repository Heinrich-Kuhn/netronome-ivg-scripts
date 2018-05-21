#!/bin/bash

VM_NAME=$1

function shutdown_vm {
  local VM_NAME=$1
  virsh dominfo ${VM_NAME} | grep -q "running" && ( \
  echo "Shutting down: ${VM_NAME}" ; \
  virsh shutdown ${VM_NAME} ; sleep 5)
}

# Gracefully shutdown VM if running
for i in $(seq 1 5);
do
  shutdown_vm ${VM_NAME}
done

# Could not gracefully shutdown - destory VM
virsh dominfo ${VM_NAME} | grep -q "running" && ( \
 virsh destroy ${VM_NAME} ; \
 sleep 2 )

virsh undefine ${VM_NAME}

