#!/bin/bash

SESSIONNAME=IVG
script_dir="$(dirname $(readlink -f $0))"
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"

apt-get install -y tmux

function wait_text {
    local pane="$1"
    local text="$2"
    if [ "$pane" == "ALL" ]; then
        wait_text 2 "$text" || exit -1
        wait_text 3 "$text" || exit -1
        return 0
    fi
    while :; do
        tmux capture-pane -t "$pane" -p \
            | grep "$text" > /dev/null \
            && return 0
        sleep 0.25
    done
    # never executed unless a timeout mechanism is implemented
    return -1
}

sshopts=()
sshopts+=( "-i" "$HOME/.ssh/netronome_key" )
sshopts+=( "-q" )
sshcmd="ssh ${sshopts[@]}"

function rsync_duts {
    local dirlist="$@"
    ropts=()
    ropts+=( "-e" "$sshcmd -l root" )
    for ipaddr in $IP_DUT1 $IP_DUT2 ; do
        rsync "${ropts[@]}" -a $dirlist $ipaddr:IVG_folder \
            || return -1
    done
    return 0
}

#######################################################################
######################### Main function ###############################
#######################################################################

# Check if TMUX variable is defined.
if [ -z "$TMUX" ]
then # $TMUX is empty, create/enter tmux session.
    tmux has-session -t $SESSIONNAME &> /dev/null
    if [ $? != 0 ]
    then
       # create session, window 0, and detach
        tmux new-session -s $SESSIONNAME -d
        tmux rename-window -t $SESSIONNAME:0 main-window
        # configure window
        tmux select-window -t $SESSIONNAME:0
        tmux split-window -h -t 0
        tmux split-window -v -t 0
        tmux split-window -v -t 1
    fi
    tmux send-keys -t 0 './run_ivg.sh' C-m
    tmux a -t $SESSIONNAME 
else # else $TMUX is not empty, start test.

    # Recreate all panes
    if [ $(tmux list-panes | wc -l) -gt 1 ] 
    then
        tmux kill-pane -a -t $SESSIONNAME":0.0"
    fi
        tmux split-window -h -t 0
        tmux split-window -v -t 0
        tmux split-window -v -t 1

    while :; do
        tmux select-pane -t 0
        clear
        echo "Please choose a option"
        echo "1) Connect to DUT's"
        echo "2) Install/Re-install Agilio-OVS"
        echo "3) Create backing image for test VM's (Only done once)"
        echo "4) Test Case 1 (Simple ping between hosts)"
        echo "5) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"
        echo "6) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)"
        echo "7) Test case 4 (SR-IOV l2fwd)"
        echo "8) Test case 5 (XVIO l2fwd)"
        echo "9) Test Case 6 (DPDK-pktgen VM-VM uni-directional SR-IOV - VXLAN)"
        echo "10) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO - VXLAN)"
        echo "11) Test Case 8 (DPDK-pktgen VM-VM bi-directional SR-IOV)"
        echo "r) Reboot host machines"        
        echo "x) Exit"
        read -p "Enter choice: " OPT
        case "$OPT" in
        
        1)  echo "1) Connect to DUT's"
            
            #Get IP's of DUT's
            read -p "Enter IP of first DUT: " IP_DUT1
            read -p "Enter IP of second DUT: " IP_DUT2

            #Copy n new public key to DUT's
            ./copy_ssh_key.sh $IP_DUT1 $IP_DUT2
            
            #SSH into DUT's
            tmux send-keys -t 2 "ssh -i ~/.ssh/netronome_key root@$IP_DUT1" C-m
            tmux send-keys -t 3 "ssh -i ~/.ssh/netronome_key root@$IP_DUT2" C-m
            
            tmux send-keys -t 2 "mkdir -p IVG_folder" C-m
            tmux send-keys -t 3 "mkdir -p IVG_folder" C-m
            ;;

        2)  echo "2) Install/Re-install Agilio-OVS"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #Check if any agilio .tar files are in the folder
            ls agilio-ovs-2.6.B-r* 2>/dev/null

            if [ $? == 2 ]; then
               echo "Could not find Agilio-OVS .tar.gz file in folder"
               echo "Please copy the Agilio-OVS .tar.gz file into the same folder as this script"
               sleep 10
            else
               tmux send-keys -t 2 "mkdir -p IVG_folder" C-m
               tmux send-keys -t 3 "mkdir -p IVG_folder" C-m
               LATEST_AOVS=$(ls agilio-ovs-2.6.B-r* 2>/dev/null | grep .tar.gz | tail -n1)
               scp -i ~/.ssh/netronome_key $LATEST_AOVS root@$IP_DUT1:/root/IVG_folder/
               scp -i ~/.ssh/netronome_key $LATEST_AOVS root@$IP_DUT2:/root/IVG_folder/

               scp -i ~/.ssh/netronome_key grub_setup.sh root@$IP_DUT1:/root/IVG_folder/
               scp -i ~/.ssh/netronome_key grub_setup.sh root@$IP_DUT2:/root/IVG_folder/

               scp -i ~/.ssh/netronome_key package_install.sh root@$IP_DUT1:/root/IVG_folder/
               scp -i ~/.ssh/netronome_key package_install.sh root@$IP_DUT2:/root/IVG_folder/
               
               tmux send-keys -t 2 "./IVG_folder/grub_setup.sh" C-m
               tmux send-keys -t 3 "./IVG_folder/grub_setup.sh" C-m
    
               wait_text 2 "Grub updated" > /dev/null
               wait_text 3 "Grub updated" > /dev/null

               tmux send-keys -t 2 "./IVG_folder/package_install.sh" C-m
               tmux send-keys -t 3 "./IVG_folder/package_install.sh" C-m

               echo "Installing Agilio-OVS on DUT's, please wait..."
               
               wait_text 2 "root@" > /dev/null
               wait_text 3 "root@" > /dev/null
                

            fi
            ;;

        3)  echo "3) Create backing image for test VM's (Only done once)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #Create working dir on DUT's
            tmux send-keys -t 2 "mkdir -p IVG_folder" C-m
            tmux send-keys -t 3 "mkdir -p IVG_folder" C-m

            #Copy VM creator script to DUT
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/vm_creator root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/vm_creator root@$IP_DUT2:/root/IVG_folder/

            #Check pre-req for installing VM's
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/check_deps.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/check_deps.sh" C-m         

            #Download cloud image to local machine
            echo "Downloading cloud image..."
            $IVG_dir/helper_scripts/0_download_cloud_image.sh
            
            #Copy downloaded image to DUT's
            echo "Copying image to DUT's"
            scp -i ~/.ssh/netronome_key /root/ubuntu-16.04-server-cloudimg-amd64-disk1.img root@$IP_DUT1:/var/lib/libvirt/images/
            scp -i ~/.ssh/netronome_key /root/ubuntu-16.04-server-cloudimg-amd64-disk1.img root@$IP_DUT2:/var/lib/libvirt/images/

            #Create backing image
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/x_create_backing_image.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/x_create_backing_image.sh" C-m
            
            echo "Creating base image for test VM's, please wait..."
               
            #Wait until base image is completed
            wait_text ALL "Base image created!"
            ;;
        
        4)  echo "4) Test Case 1 (Simple ping between hosts)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #Copy test case 1 to DUT's
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_1_ping root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_1_ping root@$IP_DUT2:/root/IVG_folder/

            #Setup test case 1
            tmux send-keys -t 2 "./IVG_folder/test_case_1_ping/setup_test_case_1.sh 10.0.0.1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1_ping/setup_test_case_1.sh 10.0.0.2" C-m

            #Wait for test case 1 setup to complete
            wait_text ALL "DONE(setup_test_case_1.sh)"

            echo "Running test case 1 - Simple ping"

            #Ping form one host
            tmux send-keys -t 2 "ping 10.0.0.2 -c 5" C-m

            ;;

        5)  echo "5) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-sriov-vm
            VM_CPUS=4
            
            echo "VM's are called $VM_BASE_NAME"
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo "Creating test VM from backing image"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_2_sriov_uni root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_2_sriov_uni root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_2_sriov_uni/1_port/setup_test_case_2.sh $VM_BASE_NAME $VM_CPUS" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_2_sriov_uni/1_port/setup_test_case_2.sh $VM_BASE_NAME $VM_CPUS" C-m
            
            wait_text ALL "DONE(setup_test_case_2.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
	    
            #Pause tmux until VM boots up 
            wait_text ALL "* Documentation:  https://help.ubuntu.com" > /dev/null
            
            sleep 1
            tmux send-keys -t 2 "cd vm_scripts/samples/DPDK-pktgen" C-m
            tmux send-keys -t 3 "cd vm_scripts/samples/DPDK-pktgen" C-m

            tmux send-keys -t 2 "./1_configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./1_configure_hugepages.sh" C-m

            sleep 1

            tmux send-keys -t 2 "./2_auto_bind_igb_uio.sh" C-m
            tmux send-keys -t 3 "./2_auto_bind_igb_uio.sh" C-m

            sleep 5

            tmux send-keys -t 2 "cd 3_dpdk_pktgen_lua_capture" C-m
            tmux send-keys -t 3 "cd 3_dpdk_pktgen_lua_capture" C-m
            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh" C-m
            
            echo "Running test case 2 - SRIOV DPDK-pktgen"
            wait_text 3 "root@" > /dev/null

            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo "copy data..."
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_shutdown_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_shutdown_vm.sh $VM_BASE_NAME" C-m
            
            
            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt SRIOV_test_run-0.txt
            else
            num=1
            while [[ -e "SRIOV_test_run-$num.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "SRIOV_test_run-$num.txt" 
            fi 
            

           ;;

        6)  echo "6) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-sriov-vxlan-vm
            VM_CPUS=4
            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.1"

            echo "VM's are called $VM_BASE_NAME"
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo "Creating test VM from backing image"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_3_sriov_vxlan_uni root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_3_sriov_vxlan_uni root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_3_sriov_vxlan_uni/1_port/setup_test_case_3.sh $VM_BASE_NAME $VM_CPUS $DST_IP $SRC_IP" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_3_sriov_vxlan_uni/1_port/setup_test_case_3.sh $VM_BASE_NAME $VM_CPUS $SRC_IP $DST_IP" C-m
            
            wait_text ALL "DONE(setup_test_case_3.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "* Documentation:  https://help.ubuntu.com" > /dev/null
            
            sleep 1
            tmux send-keys -t 2 "cd vm_scripts/samples/DPDK-pktgen" C-m
            tmux send-keys -t 3 "cd vm_scripts/samples/DPDK-pktgen" C-m

            tmux send-keys -t 2 "./1_configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./1_configure_hugepages.sh" C-m

            sleep 1

            tmux send-keys -t 2 "./2_auto_bind_igb_uio.sh" C-m
            tmux send-keys -t 3 "./2_auto_bind_igb_uio.sh" C-m

            sleep 5

            tmux send-keys -t 2 "cd 3_dpdk_pktgen_lua_capture" C-m
            tmux send-keys -t 3 "cd 3_dpdk_pktgen_lua_capture" C-m
            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh" C-m
            
            echo "Running test case 2 - SRIOV DPDK-pktgen"
            wait_text 3 "root@" > /dev/null

            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo "copy data..."
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_shutdown_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_shutdown_vm.sh $VM_BASE_NAME" C-m
            
            
            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt SRIOV_vxlan_test_run-0.txt
            else
            num=1
            while [[ -e "SRIOV_vxlan_test_run-$num.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "SRIOV_vxlan_test_run-$num.txt" 
            fi 
            
            ;;
         7)  echo "7) Test case 4 (SR-IOV l2fwd)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m
            
            read -p "Enter IP of DUT to run l2fwd VM on: " l2fwd_IP
            
            if [ $l2fwd_IP == $IP_DUT1 ]; then
            tmux_pane=2
	        vm_number=1
            else 
                tmux_pane=3
		        vm_number=2
            fi
            
            VM_BASE_NAME=netronome-l2fwd
            
            #Copy VM creator script to DUT
            scp -i ~/.ssh/netronome_key -r vm_creator root@$l2fwd_IP:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_4 root@$l2fwd_IP:/root/IVG_folder/

            echo "VM is called $VM_BASE_NAME"
            tmux send-keys -t $tmux_pane "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            
            echo "Creating test VM from backing image"
            wait_text $tmux_pane "VM has been created!" > /dev/null
            
            tmux send-keys -t $tmux_pane "./IVG_folder/test_case_4/setup_test_case_4.sh $VM_BASE_NAME-1 3" C-m
            wait_text $tmux_pane "* Documentation:  https://help.ubuntu.com" > /dev/null
            
            sleep 1
            tmux send-keys -t $tmux_pane "cd vm_scripts/samples/" C-m
            tmux send-keys -t $tmux_pane "./1_configure_hugepages.sh" C-m
            
            sleep 1

            tmux send-keys -t $tmux_pane "./2_auto_bind_igb_uio.sh" C-m
            
            sleep 1
            tmux send-keys -t $tmux_pane "cd DPDK-l2fwd" C-m
           
            tmux send-keys -t $tmux_pane "./3_run_l2fwd.sh" C-m
            
            while :; do
            read -p "Enter 'x' to kill the VM running l2fwd: " l2fwd_kill            
            
            if [ $l2fwd_kill == 'x' ]; then
                 tmux send-keys -t $tmux_pane C-c
                 sleep 1
                 tmux send-keys -t $tmux_pane "poweroff" C-m
                 sleep 1
                 tmux send-keys -t $tmux_pane "virsh undefine $VM_BASE_NAME-$vm_number" C-m
		 break
            fi        
            done

            ;;
                
            8)  echo "8) Test case 5 (XVIO l2fwd)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m
            
            read -p "Enter IP of DUT to run l2fwd VM on: " l2fwd_IP
            
            if [ $l2fwd_IP == $IP_DUT1 ]; then
            tmux_pane=2
	        vm_number=1
            else 
                tmux_pane=3
		        vm_number=2
            fi
            
            VM_BASE_NAME=netronome-l2fwd-xvio
            
            #Copy VM creator script to DUT
            scp -i ~/.ssh/netronome_key -r vm_creator root@$l2fwd_IP:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_5 root@$l2fwd_IP:/root/IVG_folder/

            echo "VM is called $VM_BASE_NAME"
            tmux send-keys -t $tmux_pane "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-$vm_number" C-m
            
            echo "Creating test VM from backing image"
            wait_text $tmux_pane "VM has been created!" > /dev/null
            
            tmux send-keys -t $tmux_pane "./IVG_folder/test_case_5/setup_test_case_5.sh $VM_BASE_NAME-$vm_number 3 2" C-m
            wait_text $tmux_pane "* Documentation:  https://help.ubuntu.com" > /dev/null

            sleep 1
            tmux send-keys -t $tmux_pane "cd vm_scripts/samples/" C-m
            tmux send-keys -t $tmux_pane "./1_configure_hugepages.sh" C-m
            
            sleep 1

            tmux send-keys -t $tmux_pane "./2_auto_bind_igb_uio.sh" C-m
            
            sleep 1
            tmux send-keys -t $tmux_pane "cd DPDK-l2fwd" C-m
           
            tmux send-keys -t $tmux_pane "./3_run_l2fwd.sh" C-m
            
            while :; do
            read -p "Enter 'x' to kill the VM running l2fwd: " l2fwd_kill            
            
            if [ $l2fwd_kill == 'x' ]; then
                 tmux send-keys -t $tmux_pane C-c
                 sleep 1
                 tmux send-keys -t $tmux_pane "poweroff" C-m
                 sleep 1
                 tmux send-keys -t $tmux_pane "virsh undefine $VM_BASE_NAME-$vm_number" C-m
		 break
            fi        
            done

            ;;


        
         9)  echo "9) Test Case 6 (DPDK-pktgen VM-VM uni-directional SR-IOV - VXLAN)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME=netronome-sriov-vm-vxlan
            echo "VM's are called $VM_BASE_NAME"
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-2" C-m
            
            echo "Creating test VM from backing image"
            wait_text 2 "VM has been created!" > /dev/null
            wait_text 3 "VM has been created!" > /dev/null

            scp -i ~/.ssh/netronome_key -r test_case_6 root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_6 root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_6/setup_test_case_6.sh $VM_BASE_NAME-1 3 10.10.10.1 10.10.10.2" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_6/setup_test_case_6.sh $VM_BASE_NAME-2 3 10.10.10.2 10.10.10.1" C-m
            
            #Pause tmux until VM boots up 
            wait_text 2 "* Documentation:  https://help.ubuntu.com" > /dev/null
            wait_text 3 "* Documentation:  https://help.ubuntu.com" > /dev/null
            
            sleep 1
            tmux send-keys -t 2 "cd vm_scripts/samples/" C-m
            tmux send-keys -t 3 "cd vm_scripts/samples/" C-m

            tmux send-keys -t 2 "./1_configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./1_configure_hugepages.sh" C-m

            sleep 1

            tmux send-keys -t 2 "./2_auto_bind_igb_uio.sh" C-m
            tmux send-keys -t 3 "./2_auto_bind_igb_uio.sh" C-m

            sleep 5

            tmux send-keys -t 2 "cd DPDK-pktgen" C-m
            tmux send-keys -t 3 "cd DPDK-pktgen" C-m

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh y" C-m
            
            echo "Running test case 6 - SRIOV DPDK-pktgen VXLAN"
            wait_text 3 "root@" > /dev/null

            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo "copy data..."
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/test_case_6/7_copy_data_dump.sh $VM_BASE_NAME-2" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/test_case_6/8_shutdown_vm.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_6/8_shutdown_vm.sh $VM_BASE_NAME-2" C-m
            
            
            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt SRIOV_test_run_vxlan-0.txt
            else
            num=1
            while [[ -e "SRIOV_test_run_vxlan-$num.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "SRIOV_test_run_vxlan-$num.txt" 
            fi 
            ;;


        10)  echo "10) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO - VXLAN)"
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME=netronome-xvio-vm-vxlan
            echo "VM's are called $VM_BASE_NAME"
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-2" C-m
            
            echo "Creating test VM from backing image"
            wait_text 2 "VM has been created!" > /dev/null
            wait_text 3 "VM has been created!" > /dev/null

            scp -i ~/.ssh/netronome_key -r test_case_7 root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_7 root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_7/setup_test_case_7.sh $VM_BASE_NAME-1 3 2 10.10.10.1 10.10.10.2" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_7/setup_test_case_7.sh $VM_BASE_NAME-2 3 2 10.10.10.2 10.10.10.1" C-m
            
            #Pause tmux until VM boots up 
            wait_text 2 "* Documentation:  https://help.ubuntu.com" > /dev/null
            wait_text 3 "* Documentation:  https://help.ubuntu.com" > /dev/null
            
            sleep 1
            tmux send-keys -t 2 "cd vm_scripts/samples/" C-m
            tmux send-keys -t 3 "cd vm_scripts/samples/" C-m

            tmux send-keys -t 2 "./1_configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./1_configure_hugepages.sh" C-m

            sleep 1

            tmux send-keys -t 2 "./2_auto_bind_igb_uio.sh" C-m
            tmux send-keys -t 3 "./2_auto_bind_igb_uio.sh" C-m

            sleep 5

            tmux send-keys -t 2 "cd DPDK-pktgen" C-m
            tmux send-keys -t 3 "cd DPDK-pktgen" C-m

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh y" C-m
            
            echo "Running test case 7 - XVIO DPDK-pktgen VXLAN"
            wait_text 3 "root@" > /dev/null

            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo "copy data..."
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/test_case_7/7_copy_data_dump.sh $VM_BASE_NAME-2" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/test_case_7/8_shutdown_vm.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_7/8_shutdown_vm.sh $VM_BASE_NAME-2" C-m
            
            
            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt XVIO_test_run_vxlan-0.txt
            else
            num=1
            while [[ -e "XVIO_test_run_vxlan-$num.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "XVIO_test_run_vxlan-$num.txt" 
            fi 

            ;;

        11)  echo "11) Test Case 8 (DPDK-pktgen VM-VM bi-directional SR-IOV)"

            tcname="test_case_8"

            VM_BASE_NAME="ns-bi-sriov"

            rsync_duts $tcname vm_creator || exit -1

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-2" C-m

            wait_text ALL "VM has been created!"

            tmux send-keys -t 2 "./IVG_folder/$tcname/setup_test_case.sh $VM_BASE_NAME-1 3" C-m
            tmux send-keys -t 3 "./IVG_folder/$tcname/setup_test_case.sh $VM_BASE_NAME-2 3" C-m

            wait_text ALL "DONE(setup_test_case.sh)"

            tmux send-keys -t 2 "./IVG_folder/$tcname/rsync-vm.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/$tcname/rsync-vm.sh $VM_BASE_NAME-2" C-m

            tmux send-keys -t 2 "./IVG_folder/$tcname/access.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/$tcname/access.sh $VM_BASE_NAME-2" C-m

            wait_text 2 "root@$VM_BASE_NAME-1"
            wait_text 3 "root@$VM_BASE_NAME-2"

            tmux send-keys -t 2 "cd vm_scripts/samples" C-m
            tmux send-keys -t 3 "cd vm_scripts/samples" C-m

            tmux send-keys -t 2 "./1_configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./1_configure_hugepages.sh" C-m

            sleep 1

            tmux send-keys -t 2 "./2_auto_bind_igb_uio.sh" C-m
            tmux send-keys -t 3 "./2_auto_bind_igb_uio.sh" C-m

            sleep 1

            tmux send-keys -t 3 "./DPDK-route/run-dpdk-route-dual.sh" C-m

            sleep 2

            tmux send-keys -t 2 "cd DPDK-pktgen" C-m
            tmux send-keys -t 2 "./run-dpdk-pktgen-bi-directional.sh" C-m

            ;;

        r)  echo "r) Reboot host machines"
            read -p "Are you sure you want to reboot DUT's (y/n): " REBOOT_ANS

            if [ $REBOOT_ANS == 'y' ]; then
                echo "Rebooting DUT's"
                tmux send-keys -t 2 "reboot" C-m
                tmux send-keys -t 3 "reboot" C-m
            fi
            ;;

        x)  echo "x) Exiting script"
            sleep 1
            tmux kill-session -t $SESSIONNAME
            exit 0
            ;;
        *)  echo "Not a valid option, try again."
            ;;
        esac
    done
fi

#######################################################################
#######################################################################
#######################################################################


