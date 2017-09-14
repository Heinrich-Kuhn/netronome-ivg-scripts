# Test Case 1: Simple VF netdev back-2-back ping

![Test Case 1 Layout](https://github.com/netronome-support/IVG/blob/master/aovs_2.6B/test_case_1/test_case_1_layout.png?raw=true)

The following steps may be followed to perform a simple ping test between two host machines that are connected back to back with a Netronome NIC.

### The scripts will:
1. Bind a VF to the **nfp_netvf** driver using **dpdk-devbind.py**
2. Assign a IP address to the netdev 
3. Create a OVS bridge and add the VF and a physical port to the bridge
4. Add a NORMAL rule to the bridge

### Example usage:

#### DUT2
```
./1_bind_netronome_nfp_netvf_driver.sh 20.0.0.2
./2_configure_AOVS.sh
./3_configure_bridge.sh
./4_configure_ovs_rules.sh
```

#### DUT1
```
./1_bind_netronome_nfp_netvf_driver.sh 20.0.0.1
./2_configure_AOVS.sh
./3_configure_bridge.sh
./4_configure_ovs_rules.sh

ping 20.0.0.2
```

### Expected output:
```
PING 20.0.0.2 (20.0.0.2) 56(84) bytes of data.
64 bytes from 20.0.0.2: icmp_seq=1 ttl=64 time=0.022 ms
64 bytes from 20.0.0.2: icmp_seq=2 ttl=64 time=0.013 ms
64 bytes from 20.0.0.2: icmp_seq=3 ttl=64 time=0.012 ms
64 bytes from 20.0.0.2: icmp_seq=4 ttl=64 time=0.012 ms
```
