# Netronome Installation Verification Guide

Various test cases are illustrated in this repo to demonstrate the advantage of smart NIC technology.  
The script can be run on one of the two devices connected back to back, or alternatively on a third device.

### To get started using this repo, first clone it:
```
git clone https://github.com/netronome-support/IVG
```
### A TMUX script will help facilitate running the test cases, first make sure TMUX is installed
```
yum -y install tmux
```
#### Run the TMUX script to start the guided IVG
```
cd /IVG/aovs2.6_B/
./run_ivg.sh
```

#### The script menu
```
Please choose a option
a) Connect to DUT's
b) Install/Re-install Agilio-OVS
c) Create backing image for test VM's (Only done once)
1) Test Case 1 (Simple ping between hosts)
2) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)
3) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)
4) Test case 4 (DPDK-Pktgen Rx -> Ixia Tx SR-IOV)
6) Test case 6 (DPDK-pktgen VM-VM uni-directional XVIO)
7) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO VXLAN)
8) Test Case 8 (DPDK-Pktgen Rx -> Ixia Tx XVIO)
11) Test Case 11 (DPDK-pktgen VM-Vm uni-directional KOVS Intel XL710)
k) Setup test case 11
r) Reboot host machines
x) Exit
Enter choice:
```

#### Execution
##### a) Connect to DUT's 

Select option a)  
Enter the two IP addresses of the test devices when prompted.  

##### b) Download and install Agilio OVS

Download the applicable file from the Netronome support site to the /root directory of the device executing the script.  
Select option b)  
The srcipt will prompt the user if the incorrect kernel is loaded

Please use option r) to reboot the devices after installing a new kernel and AOVS respectively  

###### OPTIONAL
Download the kernel packages to the /root directory of the device executing the script

##### c) Create backing image 
Select option c) to create a backing image for the VM's that will be used in the test cases.

##### Test cases
Execute the respective test cases. It is recommended that they be executed in order.  
They can also be run manually from the IVG directory.  
The test results will be stored on the device executing the script.  

##### Test Case 11 - KOVS test
Before executing test case 11, run option k) to install and configure KOVS.  
Please use option r) to reboot the devices after installing KOVS.  




