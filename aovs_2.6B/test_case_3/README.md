# Test Case 3: VM-VM - Virtio Configuration

![Test Case 2 Layout](https://github.com/netronome-support/IVG/blob/master/aovs_2.6B/test_case_2/test_case_2_layout.png?raw=true)

The following steps may be followed to setup DPDK-Pktgen inside a VM running on the first host and create a second instance of DPDK-Pktgen running inside a VM on the second host.

### The scripts will:
1. Bind two VF's to igb_uio using dpdk-devbind.py
2. Configure Agilio-OVS to use XVIO by modifying /etc/netronome.conf
3. Create a OVS bridge and add the two XVIO VF's and physical ports to the bridge
4. Add a NORMAL rule to the bridge
5. Configure Apparmor to configure the propper permissions for Libvirt
6. Modify the xml file of the VM that was created using the [VM creator](https://github.com/netronome-support/IVG/tree/master/aovs_2.6B/vm_creator/ubuntu) section

### Example usage:
Follow the steps outlined in the [VM creator](https://github.com/netronome-support/IVG/tree/master/aovs_2.6B/vm_creator/ubuntu) section of this repo to create a backing image for this test.
>**NOTE:**
>These steps should be performed on both hosts
```
./1_bind_IGB-UIO_driver.sh
./2_configure_ovs.sh
./3_configure_ovs_rules.sh
./4_configure_apparmor.sh
5_configure_guest_xml.sh <your_vm_name>

virsh start <your_vm_name>
```
To list DHCP leases of VM's
```
virsh net-dhcp-leases default
```
Connect to your newly created VM
```
ssh root@<VM_IP>
```
Run the following scripts on the receiving VM
```
/root/vm_scripts/samples/DPDK-pktgen/1_configure_hugepages.sh
/root/vm_scripts/samples/DPDK-pktgen/2_auto_bind_igb_uio.sh
/root/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/0_run_dpdk-pktgen_uni-rx.sh
```
Run the following scripts on the transmitting VM
```
/root/vm_scripts/samples/DPDK-pktgen/1_configure_hugepages.sh
/root/vm_scripts/samples/DPDK-pktgen/2_auto_bind_igb_uio.sh
/root/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/1_run_dpdk-pktgen_uni-tx.sh
```
> **NOTE:**
> The following packet sizes will be tested
> - 64, 128, 256, 512, 1024, 1280, 1518

The receiving VM will log the results of the test and save it to a **comma seperated file** called capture.txt
This file can be found at **/root/capture.txt** of the receving VM
