#!/bin/bash

SESSIONNAME=IVG
script_dir="$(dirname $(readlink -f $0))"
export IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"

echo "64000" > /root/IVG/aovs_2.6B/flow_setting.txt

#Check if TMUX is installed
grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
apt-get install -y tmux
fi

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
yum -y install tmux
fi

#Some colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


#Pause TMUX function
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

function flows_config {

    if [ ! -f /root/IVG/aovs_2.6B/flow_setting.txt ]; then
        return 0
    fi
    
    local flows=$(cat /root/IVG/aovs_2.6B/flow_setting.txt)
    
    flows=$(( $flows/2 ))

    if [[ "$flows" -lt 1 ]]; then
        skip=1
    fi
    if [[ "$flows" -gt 64000 ]]; then
        skip=64000
    fi

    flows_tot=$(echo "obase=16; $flows" | bc)
    while [ ${#flows_tot} -lt 12 ]; do
        flows_tot="0$flows_tot"
    done

    flows_tot="${flows_tot:0:2}:${flows_tot:2:2}:${flows_tot:4:2}:${flows_tot:6:2}:${flows_tot:8:2}:${flows_tot:10:2}"

    tmux send-keys -t 2 "sed -i '/.*pktgen.src_mac(tonumber(c).*max.*/c\    pktgen.src_mac(tonumber(c), \"max\", \"$flows_tot\");' /root/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/unidirectional_transmitter.lua" C-m
    tmux send-keys -t 2 "sed -i '/.*pktgen.src_mac(tonumber(c).*max.*/c\    pktgen.src_mac(tonumber(c), \"max\", \"$flows_tot\");' /root/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/unidirectional_transmitter_vxlan.lua" C-m
    
    return 0

        
}

case "$CLOUD_IMAGE_OS" in
  "centos")
    VM_MGMT_DIR="\$HOME/IVG_folder/vm_creator/centos"
    ;;
  *)
    # Ubuntu is the default
    VM_MGMT_DIR="\$HOME/IVG_folder/vm_creator/ubuntu"
    ;;
esac

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
        DUT_CONNECT=0

    while :; do
        tmux select-pane -t 0
        clear

        flow=$(cat /root/IVG/aovs_2.6B/flow_setting.txt)

        echo "Please choose a option"
        echo ""
        echo "Flow count currently set for tests: $flow"
        echo ""
        echo "a) Connect to DUT's"
        echo "b) Install/Re-install Agilio-OVS"
        echo "c) Create backing image for test VM's (Only done once)"
        echo "1) Test Case 1 (Simple ping between hosts)"
        echo "2) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"
        echo "3) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)"
        echo "4) Test case 4 (DPDK-Pktgen Rx -> Ixia Tx SR-IOV)"
        echo "6) Test case 6 (DPDK-pktgen VM-VM uni-directional XVIO)"
        echo "7) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO VXLAN)"
        echo "8) Test Case 8 (DPDK-Pktgen Rx -> Ixia Tx XVIO)"
        echo "k) Setup KOVS"
        echo "10) Test Case 10 (DPDK-pktgen VM-VM uni-directional KOVS VXLAN Intel XL710)"
        echo "11) Test Case 11 (DPDK-pktgen VM-VM uni-directional KOVS Intel XL710)"
        echo "r) Reboot host machines"
        echo "d) Set up DPDK OVS"
        echo "k) Set up KOVS"        
        echo "f) Set amount of flows"
        echo "x) Exit"
        echo ""
        read -p "Enter choice: " OPT
        case "$OPT" in
        
        a)  echo "a) Connect to DUT's"
            
            #Get IP's of DUT's
            read -p "Enter IP of first DUT: " IP_DUT1
            read -p "Enter IP of second DUT: " IP_DUT2

            export IVG_SERVERS_IPADDR_LIST="$IP_DUT1 $IP_DUT2"

            #Copy n new public key to DUT's
            $IVG_dir/helper_scripts/copy_ssh_key.sh $IP_DUT1 $IP_DUT2

            sleep 2

            #SSH into DUT's
            tmux send-keys -t 2 "ssh -i ~/.ssh/netronome_key root@$IP_DUT1" C-m
            tmux send-keys -t 3 "ssh -i ~/.ssh/netronome_key root@$IP_DUT2" C-m
            
            sleep 2

            tmux send-keys -t 2 "rm -r IVG_folder" C-m
            tmux send-keys -t 3 "rm -r IVG_folder" C-m

            tmux send-keys -t 2 "mkdir -p IVG_folder" C-m
            tmux send-keys -t 3 "mkdir -p IVG_folder" C-m

            tmux send-keys -t 2 "cd IVG_folder" C-m
            tmux send-keys -t 3 "cd IVG_folder" C-m

            tmux send-keys -t 2 "mkdir -p aovs_2.6B" C-m
            tmux send-keys -t 3 "mkdir -p aovs_2.6B" C-m

            tmux send-keys -t 2 "cd aovs_2.6B" C-m
            tmux send-keys -t 3 "cd aovs_2.6B" C-m

            tmux send-keys -t 2 "mkdir -p logs" C-m
            tmux send-keys -t 3 "mkdir -p logs" C-m

            sleep 1

            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            #Copy VM creator script to DUT
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/vm_creator root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/vm_creator root@$IP_DUT2:/root/IVG_folder/

            sleep 1

            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/inventory.sh > /root/IVG_folder/aovs_2.6B/logs/dut_1.log" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/inventory.sh > /root/IVG_folder/aovs_2.6B/logs/dut_2.log" C-m

            sleep 1

            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/dut_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/dut_2.log $IVG_dir/aovs_2.6B/logs/
            
            
            DUT_CONNECT=1
            ;;

        b)  echo "b) Install/Re-install Agilio-OVS"
            
            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Installation_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Installation_DUT_2.log" C-m           

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi
          
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #Check if any agilio .tar files are in the folder
            cd 
            ls agilio-ovs-2.6.B-r* 2>/dev/null

            if [ $? == 2 ]; then
               echo -e "${RED}Could not find Agilio-OVS .tar.gz file in folder${NC}"
               echo -e "${RED}Please copy the Agilio-OVS .tar.gz file into the root folder of this machine${NC}"
               sleep 10
            else
               #tmux send-keys -t 2 "mkdir -p IVG_folder" C-m
               #tmux send-keys -t 3 "mkdir -p IVG_folder" C-m
               LATEST_AOVS=$(ls agilio-ovs-2.6.B-r* 2>/dev/null | grep .tar.gz | tail -n1)
               
               scp -i ~/.ssh/netronome_key $LATEST_AOVS root@$IP_DUT1:/root/
               scp -i ~/.ssh/netronome_key $LATEST_AOVS root@$IP_DUT2:/root/

               tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/configure_grub.sh" C-m
               tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/configure_grub.sh" C-m
    
               wait_text 2 "Grub updated" > /dev/null
               wait_text 3 "Grub updated" > /dev/null

               tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/package_install.sh" C-m
               tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/package_install.sh" C-m

               echo -e "${GREEN}Installing Agilio-OVS on DUT's, please wait...${NC}"
               
               wait_text ALL "DONE(package_install.sh)"

               echo -e "${GREEN}Please reboot DUT's using the 'r' option${NC}"
               sleep 10

            fi

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Installation_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Installation_DUT_2.log $IVG_dir/aovs_2.6B/logs/

            ;;

        c)  echo "c) Create backing image for test VM's (Only done once)"

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_2.log" C-m
            
            if [ $DUT_CONNECT == 0 ]; then
                echo "Please connect to DUT's first"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            # Copy VM creator script to DUT
            $IVG_dir/helper_scripts/rsync-servers.sh \
                $IVG_dir/aovs_2.6B/vm_creator \
                /root/IVG_folder \
                || exit -1

            # Download cloud image to local machine and update DUTs
            $IVG_dir/helper_scripts/download_cloud_image.sh \
                || exit -1

            # Create backing image
            tmux send-keys -t 2 "$VM_MGMT_DIR/x_create_backing_image.sh" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/x_create_backing_image.sh" C-m

            echo -e "${GREEN}Creating base image for test VM's, please wait...${NC}"

            wait_text ALL "Base image created!"

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_2.log $IVG_dir/aovs_2.6B/logs/

            ;;

        1)  echo "1) Test Case 1 (Simple ping between hosts)"


            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_2.log" C-m
            
            if [ $DUT_CONNECT == 0 ]; then
                echo "Please connect to DUT's first"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #Copy test case 1 to DUT's
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_1_ping root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_1_ping root@$IP_DUT2:/root/IVG_folder/

            #Setup test case 1
            tmux send-keys -t 2 "./IVG_folder/test_case_1_ping/setup_test_case_1.sh -i 10.0.0.1" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1_ping/setup_test_case_1.sh -i 10.0.0.2" C-m

            echo -e "${GREEN}* Setting up test case 1${NC}"
            
            #Wait for test case 1 setup to complete
            wait_text ALL "DONE(setup_test_case_1.sh)"

            echo -e "${GREEN}* Running test case 1 - Simple ping${NC}"

            #Ping form one host
            tmux send-keys -t 2 "ping 10.0.0.2 -c 5" C-m

            sleep 6

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_2.log $IVG_dir/aovs_2.6B/logs/

            ;;

        2)  echo "2) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"


             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_2.log" C-m
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-sriov-vm
            VM_CPUS=4
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_2_sriov_uni root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_2_sriov_uni root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_2_sriov_uni/1_port/setup_test_case_2.sh $VM_BASE_NAME $VM_CPUS" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_2_sriov_uni/1_port/setup_test_case_2.sh $VM_BASE_NAME $VM_CPUS" C-m
            
            echo -e "${GREEN}* Setting up test case 2${NC}"

            wait_text ALL "DONE(setup_test_case_2.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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

            flows_config

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh n" C-m
            
            #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_2
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_2
            

            echo -e "${GREEN}* Running test case 2 - SRIOV DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null


            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_2
            
            
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_2.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_2.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_2_flow_count.txt $script_dir
            sleep 2

            
            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
            if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "SRIOV_test_run_parsed-0-f$flow_count.txt"
            else
               num=1
               while [[ -e "SRIOV_test_run_parsed-$num-f*.txt" ]]; do
                  (( num++ ))
               done
               mv parsed_data.txt "SRIOV_test_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "SRIOV_test_run-0-f$flow_count.txt"
            else
               num=1
               while [[ -e "SRIOV_test_run-$num-f*.txt" ]]; do
                  (( num++ ))
               done
               mv capture.txt "SRIOV_test_run-$num-f$flow_count.txt" 
            fi

            sleep 1

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_2.log $IVG_dir/aovs_2.6B/logs/
            

           ;;

        3)  echo "3) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_2.log" C-m
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-sriov-vxlan-vm
            VM_CPUS=4
            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.1"

            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_3_sriov_vxlan_uni root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_3_sriov_vxlan_uni root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_3_sriov_vxlan_uni/1_port/setup_test_case_3.sh $VM_BASE_NAME $VM_CPUS $DST_IP $SRC_IP" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_3_sriov_vxlan_uni/1_port/setup_test_case_3.sh $VM_BASE_NAME $VM_CPUS $SRC_IP $DST_IP" C-m
            
            echo -e "${GREEN}* Setting up test case 3${NC}"
            wait_text ALL "DONE(setup_test_case_3.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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

            flows_config

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh y" C-m
            
            sleep 5
            echo -e "${GREEN}* Running test case 3 - XVIO DPDK-pktgen${NC}"
            sleep 5
            
             #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_3
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_3
            
            echo -e "${GREEN}* Running test case 3 - SRIOV VXLAN DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null

            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')


            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_3

            #Run data parser
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null

            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_3.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_3.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_3_flow_count.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
            if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "SRIOV_vxlan_test_run_parsed-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "SRIOV_vxlan_test_run_parsed-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv parsed_data.txt "SRIOV_vxlan_test_run_parsed-$num-f$flow_count.txt" 
            fi


            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "SRIOV_vxlan_test_run-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "SRIOV_vxlan_test_run-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "SRIOV_vxlan_test_run-$num-f$flow_count.txt" 
            fi 

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_2.log $IVG_dir/aovs_2.6B/logs/
            
            ;;

         4)  echo "4) Test case 4 (DPDK-Pktgen Rx -> Ixia Tx SR-IOV)"
            
            ;;
                
         5)  echo "5) Test case 5 (Ixia Tx & Rx - VM L2FWD SR-IOV)"
            
           

            ;;


        
         6)  echo "6) Test Case 6 (DPDK-pktgen VM-VM uni-directional XVIO)"


             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_2.log" C-m
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-xvio-vm
            VM_CPUS=4
            XVIO_CPUS=2
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_6_xvio_uni root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_6_xvio_uni root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_6_xvio_uni/1_port/setup_test_case_6.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_6_xvio_uni/1_port/setup_test_case_6.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS" C-m
            
            echo -e "${GREEN}* Setting up test case 6${NC}"
            wait_text ALL "DONE(setup_test_case_6.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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

            flows_config

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh n" C-m
            sleep 5
            echo -e "${GREEN}* Running Test Case 6 (DPDK-pktgen VM-VM uni-directional XVIO)${NC}"
            
             #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_6
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_6
            
            echo -e "${GREEN}* Running test case 6 - XVIO DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null

            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_6

            #Run data parser
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null
            
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_6.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_6.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_6_flow_count.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
            if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "XVIO_test_run_parsed-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "XVIO_test_run_parsed-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv parsed_data.txt "XVIO_test_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "XVIO_test_run-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "XVIO_test_run-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "XVIO_test_run-$num-f$flow_count.txt" 
            fi 

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_2.log $IVG_dir/aovs_2.6B/logs/
            
            ;;


        7)  echo "7) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO - VXLAN)"


             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_2.log" C-m
             
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-xvio-vxlan-vm
            VM_CPUS=4
            XVIO_CPUS=2
            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.1"

            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_7_xvio_vxlan_uni root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_7_xvio_vxlan_uni root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_7_xvio_vxlan_uni/1_port/setup_test_case_7.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS $DST_IP $SRC_IP" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_7_xvio_vxlan_uni/1_port/setup_test_case_7.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS $SRC_IP $DST_IP" C-m
            
            echo -e "${GREEN}* Setting up test case 7${NC}"
            wait_text ALL "DONE(setup_test_case_7.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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

            flows_config

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh y" C-m
            sleep 5
            echo -e "${GREEN}* Running test case 7 - VXIO VXLAN${NC}"
            
             #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_7
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_7
            

            echo -e "${GREEN}* Running test case 7 - XVIO VXLAN DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null

            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_7

            #Run data parser
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null
            
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_7.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_7.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_7_flow_count.txt $script_dir
            sleep 2

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
            if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "XVIO_vxlan_test_run_parsed-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "XVIO_vxlan_test_run_parsed-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv parsed_data.txt "XVIO_vxlan_test_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "XVIO_vxlan_test_run-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "XVIO_vxlan_test_run-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "XVIO_vxlan_test_run-$num-f$flow_count.txt" 
            fi 

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_2.log $IVG_dir/aovs_2.6B/logs/
          

            ;;

        8)  echo "8) Test Case 8 (DPDK-pktgen VM-VM bi-directional SR-IOV)"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_8_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_8_DUT_2.log" C-m

            tcname="test_case_8"

            VM_BASE_NAME="ns-bi-sriov"

            rsync_duts $tcname vm_creator || exit -1

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME-1" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME-2" C-m

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


            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_8_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_8_DUT_2.log $IVG_dir/aovs_2.6B/logs/

            ;;


        10)  echo "10) Test Case 10 (DPDK-pktgen VM-Vm uni-directional KOVS VXLAN Intel XL710)"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_2.log" C-m

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.1"

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-kovs-vxlan-intel-vm
            VM_CPUS=4
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_10_kovs_vxlan_uni_intel root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_10_kovs_vxlan_uni_intel root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_10_kovs_vxlan_uni_intel/setup_test_case_10.sh $VM_BASE_NAME $DST_IP $SRC_IP" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_10_kovs_vxlan_uni_intel/setup_test_case_10.sh $VM_BASE_NAME $SRC_IP $DST_IP" C-m
            
            echo -e "${GREEN}* Setting up test case 10${NC}"

            wait_text ALL "DONE(setup_test_case_10.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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

            flows_config

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh y" C-m
            
            #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_10
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_10
            

            echo -e "${GREEN}* Running test case 10 - DPDK-Pktgen KOVS VXLAN Intel XL710${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null

            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_10
            
            
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_10.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_10.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_10_flow_count.txt $script_dir
            sleep 2

            
            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
             if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "KOVS_vxlan_test_run_parsed-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "KOVS_test_vxlan_run_parsed-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv parsed_data.txt "KOVS_test_vxlan_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "KOVS_vxlan_test_run-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "KOVS_vxlan_test_run-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "KOVS_vxlan_test_run-$num-f$flow_count.txt" 
            fi


            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_2.log $IVG_dir/aovs_2.6B/logs/
            ;;



         11)  echo "11) Test Case 11 (DPDK-pktgen VM-VM uni-directional KOVS Intel XL710)"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_2.log" C-m

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-kovs-intel-vm
            VM_CPUS=4
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_11_kovs_uni_intel root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_11_kovs_uni_intel root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_11_kovs_uni_intel/setup_test_case_11.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_11_kovs_uni_intel/setup_test_case_11.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Setting up test case 11${NC}"

            wait_text ALL "DONE(setup_test_case_11.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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


            flows_config
            
            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh n" C-m
            
            #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_11
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_11
            

            echo -e "${GREEN}* Running test case 11 - DPDK-Pktgen KOVS Intel XL710${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null

            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_11
            
            
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_11.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_11.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_11_flow_count.txt $script_dir
            sleep 2

            
            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
             if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "KOVS_test_run_parsed-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "KOVS_test_run_parsed-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv parsed_data.txt "KOVS_test_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "KOVS_test_run-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "KOVS_test_run-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "KOVS_test_run-$num-f$flow_count.txt" 
            fi

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_2.log $IVG_dir/aovs_2.6B/logs/
            ;;
    
         12)  echo "12) Test Case 12 (DPDK-pktgen VM-VM uni-directional DPDK OVS Intel XL710)"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_2.log" C-m

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            #scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            VM_BASE_NAME=netronome-dpdk-ovs-intel-vm
            VM_CPUS=4
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_12_dpdk_ovs_uni_intel root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_12_dpdk_ovs_uni_intel root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_12_dpdk_ovs_uni_intel/setup_test_case_12.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_12_dpdk_ovs_uni_intel/setup_test_case_12.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Setting up test case 12${NC}"

            wait_text ALL "DONE(setup_test_case_12.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            #Pause tmux until VM boots up 
            wait_text ALL "WELCOME"
            
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


            flows_config
            
            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh n" C-m
            
            #CPU meas start
            echo -e "${GREEN}* Starting CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_12
            ssh -tt -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_12
            

            echo -e "${GREEN}* Running test case 11 - DPDK-Pktgen KOVS Intel XL710${NC}"
            sleep 5
            wait_text 3 "Test run complete" > /dev/null

            # Ouput flow count to text file
            flow_count=$(ssh -i ~/.ssh/netronome_key root@$IP_DUT2 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh -i ~/.ssh/netronome_key root@$IP_DUT2 /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_12
            
            
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!" > /dev/null
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/capture.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/parsed_data.txt $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_12.csv $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_12.html $script_dir
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/test_case_12_flow_count.txt $script_dir
            sleep 2

            
            tmux send-keys -t 2 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/y_vm_shutdown.sh $VM_BASE_NAME" C-m
            
            
             if [[ ! -e "parsed_data.txt" ]]; then
               mv parsed_data.txt "DPDK_OVS_test_run_parsed-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "DPDK_OVS_test_run_parsed-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv parsed_data.txt "DPDK_OVS_test_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
               mv capture.txt "DPDK_OVS_test_run-0-f$flow_count.txt"
            else
            num=1
            while [[ -e "DPDK_OVS_test_run-$num-f$flow_count.txt" ]]; do
              (( num++ ))
            done
            mv capture.txt "DPDK_OVS_test_run-$num-f$flow_count.txt" 
            fi


            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_2.log $IVG_dir/aovs_2.6B/logs/
            ;;

        k)  echo "k) Setup KOVS"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_2.log" C-m

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_10_kovs_vxlan_uni_intel root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_10_kovs_vxlan_uni_intel root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_10_kovs_vxlan_uni_intel/setup_test_case_install_10.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_10_kovs_vxlan_uni_intel/setup_test_case_install_10.sh" C-m

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/configure_grub_kovs.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/configure_grub_kovs.sh" C-m

            echo -e "${GREEN}* Installing KOVS${NC}"

            wait_text ALL "DONE(setup_test_case_10_install.sh)"

            echo -e "${GREEN}Grub has been configured. Please reboot DUT's with 'r'${NC}"

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_2.log $IVG_dir/aovs_2.6B/logs/


            ;;

        d)  echo "d) Setup DPDK OVS"

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Setup_DPDK_OVS_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Setup_DPDK_OVS_DUT_2.log" C-m
           
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/helper_scripts root@$IP_DUT2:/root/IVG_folder/

            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_12_dpdk_ovs_uni_intel root@$IP_DUT1:/root/IVG_folder/
            scp -i ~/.ssh/netronome_key -r $IVG_dir/aovs_2.6B/test_case_12_dpdk_ovs_uni_intel root@$IP_DUT2:/root/IVG_folder/

            tmux send-keys -t 2 "./IVG_folder/test_case_12_dpdk_ovs_uni_intel/setup_test_case_install_12.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_12_dpdk_ovs_uni_intel/setup_test_case_install_12.sh" C-m

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/configure_grub_kovs.sh" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/configure_grub_kovs.sh" C-m

            echo -e "${GREEN}* Installing DPDK-OVS${NC}"

            wait_text ALL "DONE(setup_test_case_12_install.sh)"

            echo -e "${GREEN}Grub has been configured. Please reboot DUT's with 'r'${NC}" 

            sleep 1

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp -i ~/.ssh/netronome_key root@$IP_DUT1:/root/IVG_folder/aovs_2.6B/logs/Setup_DPDK_OVS_DUT_1.log $IVG_dir/aovs_2.6B/logs/
            scp -i ~/.ssh/netronome_key root@$IP_DUT2:/root/IVG_folder/aovs_2.6B/logs/Setup_DPDK_OVS_DUT_2.log $IVG_dir/aovs_2.6B/logs/
		;;	


        f)  echo "f) Set amount of flows" 
            read -p "Enter amount of flows for next test: " FLOW_COUNT
        
            echo $FLOW_COUNT > /root/IVG/aovs_2.6B/flow_setting.txt
            echo "Flows set to $FLOW_COUNT"

            sleep 3
        ;;



        r)  echo "r) Reboot host machines"
            
            if [ $DUT_CONNECT == 0 ]; then
                echo "Please connect to DUT's first"
                sleep 5
                continue
            fi

            read -p "Are you sure you want to reboot DUT's (y/n): " REBOOT_ANS

            if [ $REBOOT_ANS == 'y' ]; then
                echo "Rebooting DUT's"
                tmux send-keys -t 2 "reboot" C-m
                tmux send-keys -t 3 "reboot" C-m

            #Code if running from orch

            sleep 10

            echo -e "${GREEN}Adding 5 min sleep while DUT's reboot${NC}"
            counter=0
            while [ $counter -lt 30 ];
            do
                sleep 10
                counter=$((counter+1))
                echo "counter: $counter"
                ip=$IP_DUT1
                echo "ip: $ip"
                if [ ! -z "$ip" ]; then
                    nc -w 2 -v $ip 22 </dev/null
                    if [ $? -eq 0 ]; then
                        counter=$((counter+30))
                        echo "end"
                    fi
                fi
            done
            
            echo -e "${GREEN} DUT's are back online. Connect to them using option 'a'${NC}"
            sleep 5
            DUT_CONNECT=0
            

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


