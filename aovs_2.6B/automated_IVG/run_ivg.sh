#!/bin/bash

SESSIONNAME=IVG
script_dir="$(dirname $(readlink -f $0))"

apt-get install -y tmux

function wait_text {
  while :; do
          tmux capture-pane -t $1 -p | grep "$2" && return 0
       done
       # never executed unless a timeout mechanism is implemented
       return 1
EOT
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
        echo "6) Test Case 3 (DPDK-pktgen VM-VM uni-directional XVIO)"
        echo "7) Test case 4 SR-IOV l2fwd"        
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
            
            tmux send-keys -t 2 "mkdir IVG_folder" C-m
            tmux send-keys -t 3 "mkdir IVG_folder" C-m
            ;;

        2)  echo "2) Install/Re-install Agilio-OVS"
            
            #Check if any agilio .tar files are in the folder
            ls agilio-ovs-2.6.B-r* 2>/dev/null

            if [ $? == 2 ]; then
               echo "Could not find Agilio-OVS .tar.gz file in folder"
               echo "Please copy the Agilio-OVS .tar.gz file into the same folder as this script"
               sleep 10
            else
               
               tmux send-keys -t 2 "mkdir IVG_folder" C-m
               tmux send-keys -t 3 "mkdir IVG_folder" C-m
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
            
            #Create working dir on DUT's
            tmux send-keys -t 2 "mkdir IVG_folder" C-m
            tmux send-keys -t 3 "mkdir IVG_folder" C-m

            #Copy VM creator script to DUT
            scp -i ~/.ssh/netronome_key -r vm_creator root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r vm_creator root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/check_deps.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/check_deps.sh" C-m         

            #Download cloud image to local machine
            echo "Downloading cloud image..."
            ./0_download_cloud_image.sh
            
            echo "Copying image to DUT's"
            scp -i ~/.ssh/netronome_key ubuntu-16.04-server-cloudimg-amd64-disk1.img root@$IP_DUT1:/var/lib/libvirt/images/
            scp -i ~/.ssh/netronome_key ubuntu-16.04-server-cloudimg-amd64-disk1.img root@$IP_DUT2:/var/lib/libvirt/images/

            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/x_create_backing_image.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/x_create_backing_image.sh" C-m
            
            echo "Creating base image for test VM's, please wait..."
               
               wait_text 2 "Base image created!" > /dev/null
               wait_text 3 "Base image created!" > /dev/null

            ;;
        
        4)  echo "4) Test Case 1 (Simple ping between hosts)"
            
            scp -i ~/.ssh/netronome_key -r test_case_1 root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_1 root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_1/1_bind_netronome_nfp_netvf_driver.sh 10.0.0.1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1/1_bind_netronome_nfp_netvf_driver.sh 10.0.0.2" C-m

            echo "Running test case 1 - Simple ping"
            wait_text 3 "root@" > /dev/null

            tmux send-keys -t 2 "./IVG_folder/test_case_1/2_configure_bridge.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1/2_configure_bridge.sh" C-m

            sleep 2

            tmux send-keys -t 2 "./IVG_folder/test_case_1/3_configure_ovs_rules.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1/3_configure_ovs_rules.sh" C-m

            wait_text 3 "actions=NORMAL" > /dev/null
            sleep 2 

            tmux send-keys -t 2 "ping 10.0.0.2 -c 5" C-m


            ;;
        5)  echo "5) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"
            
            VM_BASE_NAME=netronome-sriov-vm
            echo "VM's are called $VM_BASE_NAME"
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-2" C-m
            
            echo "Creating test VM from backing image"
            wait_text 2 "VM has been created!" > /dev/null
            wait_text 3 "VM has been created!" > /dev/null

            scp -i ~/.ssh/netronome_key -r test_case_2 root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_2 root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_2/setup_test_case_2.sh $VM_BASE_NAME-1 3" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_2/setup_test_case_2.sh $VM_BASE_NAME-2 3" C-m
            
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
            tmux send-keys -t 3 "./IVG_folder/test_case_2/7_copy_data_dump.sh $VM_BASE_NAME-2" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/test_case_2/8_shutdown_vm.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_2/8_shutdown_vm.sh $VM_BASE_NAME-2" C-m
            
            
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

        6)  echo "6) Test Case 3 (DPDK-pktgen VM-VM uni-directional XVIO)"
            

            scp -i ~/.ssh/netronome_key configure_hugepages.sh root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key configure_hugepages.sh root@$IP_DUT2:/root/IVG_folder/
             

            sleep 2
           tmux send-keys -t 2 "./IVG_folder/configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/configure_hugepages.sh" C-m
            
            
            sleep 2
        
            VM_BASE_NAME=netronome-xvio-vm
            echo "VM's are called $VM_BASE_NAME"
            tmux send-keys -t 2 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/vm_creator/ubuntu/y_create_vm_from_backing.sh $VM_BASE_NAME-2" C-m

            echo "Creating test VM from backing image"
            wait_text 2 "VM has been created!" > /dev/null
            wait_text 3 "VM has been created!" > /dev/null

            scp -i ~/.ssh/netronome_key -r test_case_3 root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r test_case_3 root@$IP_DUT2:/root/IVG_folder/
            
            
            sleep 2
            tmux send-keys -t 2 "rmmod vfio-pci" C-m
            tmux send-keys -t 3 "rmmod vfio-pci" C-m
            sleep 2

            
            tmux send-keys -t 2 "./IVG_folder/test_case_3/setup_test_case_3.sh $VM_BASE_NAME-1 3 2" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_3/setup_test_case_3.sh $VM_BASE_NAME-2 3 2" C-m
            
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

            tmux send-keys -t 2 "cd 3_dpdk_pktgen_lua_capture" C-m
            tmux send-keys -t 3 "cd 3_dpdk_pktgen_lua_capture" C-m

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh" C-m
            
            echo "Running test case 2 - SRIOV DPDK-pktgen"
            wait_text 3 "root@" > /dev/null

            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m

            tmux send-keys -t 3 "./IVG_folder/test_case_3/7_copy_data_dump.sh $VM_BASE_NAME-2" C-m
            
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/test_case_3/8_shutdown_vm.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_3/8_shutdown_vm.sh $VM_BASE_NAME-2" C-m
            
            
            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt XVIO_test_run-0.txt
            else
            num=1
            while [[ -e "XVIO_test_run-$num.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "XVIO_test_run-$num.txt" 
            fi
            ;;
         7)  echo "7) Test case 4 (SR-IOV l2fwd)"
            
            
            read -p "Enter IP of DUT to run l2fwd VM on: " l2fwd_IP
            
            if [ $l2fwd_IP == $IP_DUT1 ]; then
            tmux_pane=2
            else 
                tmux_pane=3
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
            tmux send-keys -t $tmux_pane "cd vm_scripts/samples/DPDK-l2fwd" C-m
           
            tmux send-keys -t $tmux_pane "./3_run_l2fwd.sh" C-m
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


