# Test Case 8: VM-VM - XVIO Ixia Uni-Directional

![Test Case 8 Layout](https://github.com/netronome-support/IVG/blob/master/aovs_2.6B/test_case_3/test_case_3_layout.png?raw=true)

The following steps may be followed to setup DPDK-Pktgen inside a VM running on the first host and create a second instance of DPDK-Pktgen running inside a VM on the second host.

### The scripts will:
1. Setup **hugepages** for XVIO to use
2. Bind two VF's to **igb_uio** using **dpdk-devbind.py**
3. Configure Agilio-OVS to use XVIO by modifying /etc/netronome.conf
4. Create a OVS bridge and add the two XVIO VF's and physical ports to the bridge
5. Add simple in-out rules to this bridge
6. Configure **apparmor** to allow the propper permissions for Libvirt
7. Modify the xml file of the VM that was created using the [VM creator](https://github.com/netronome-support/IVG/tree/master/aovs_2.6B/vm_creator/ubuntu) section

### Example usage:
Follow the steps outlined in the [VM creator](https://github.com/netronome-support/IVG/tree/master/aovs_2.6B/vm_creator/ubuntu) section of this repo to create a backing image for this test.

```
./0_configure_hugepages.sh
./1_bind_IGB-UIO_driver.sh
./2_configure_ovs.sh <number_of_xvio_cpu's>
./3_configure_ovs_rules.sh
./4_configure_apparmor.sh
./5_configure_guest_xml.sh <your_vm_name>
./6_vm_pinning <vm_name> <number_of_vm_cpu's> <number_of_xvio_cpu's>

Alternativly, you can call the **setup_test_case_8**.sh script and it will in turn call all the above mentioned scripts in sequence.
```
./setup_test_case_8.sh <vm_name> <number_of_cpu's> <number_of_xvio_cpu's>
```

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
If you want to transmit traffic with DPDK-Pktgen and let **Ixia recevie** this traffic, run the follow scripts inside the VM:
```
/root/vm_scripts/samples/DPDK-pktgen/1_configure_hugepages.sh
/root/vm_scripts/samples/DPDK-pktgen/2_auto_bind_igb_uio.sh
/root/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/1_run_dpdk-pktgen_uni-Tx.sh
```
> **NOTE:**
> The following packet sizes will be tested
> - 64, 128, 256, 512, 1024, 1280, 1518

If you want to transmit traffic with Ixia and let **DPDK-Pktgen recevie** this traffic, run the follow scripts inside the VM:
```
/root/vm_scripts/samples/DPDK-pktgen/1_configure_hugepages.sh
/root/vm_scripts/samples/DPDK-pktgen/2_auto_bind_igb_uio.sh
/root/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/0_run_dpdk-pktgen_uni-rx.sh
```
> **NOTE:**
> The receiving VM has a 60 second timeout if no traffic is received. Th transmit script must be started within 60 seconds of starting the transmitting script. This also means that the receving script will automatically timeout after 60 seconds once the test is completed

The receiving VM will log the results of the test and save it to a **comma seperated file** called capture.txt
This file can be found at **/root/capture.txt** of the receving VM
