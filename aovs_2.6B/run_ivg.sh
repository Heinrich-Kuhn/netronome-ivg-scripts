#!/bin/bash

SESSIONNAME=IVG
script_dir="$(dirname $(readlink -f $0))"
export IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"

# IVG Local Configuration Directory
ivg_config_dir="$HOME/.config/ivg"
mkdir -p $ivg_config_dir \
    || exit -1

# IVG Sticky Settings
ivg_cfg="$ivg_config_dir/settings.cfg"

# IVG Log Capture Directory
capdir="$IVG_dir/aovs_2.6B/logs"
mkdir -p $capdir \
    || exit -1

echo "64000" > /root/IVG/aovs_2.6B/flow_setting.txt

#Check if TMUX is installed
grep ID_LIKE /etc/os-release | grep -q debian
if [ $? -eq 0 ]; then
    apt-get install -y tmux bc
fi

grep  ID_LIKE /etc/os-release | grep -q fedora
if [ $? -eq 0 ]; then
    yum -y install tmux bc
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

# Send command to DUTs
function tmux_run_cmd {
    local pane="$1"
    shift 1
    local cmd="$@"
    printf "%s %-4s -- %s\n" \
        "$(date +'%Y-%m-%d %H:%M:%S')" "$pane" "$cmd" \
        >> $capdir/tmux-cmd.log
    if [ "$pane" == "ALL" ] || [ "$pane" == "DUT1" ]; then
        tmux send-keys -t 2 "$cmd" C-m
    fi
    if [ "$pane" == "ALL" ] || [ "$pane" == "DUT2" ]; then
        tmux send-keys -t 3 "$cmd" C-m
    fi
}

sshopts=()
sshopts+=( "-i" "$HOME/.ssh/netronome_key" )
sshopts+=( "-q" )
sshcmd="ssh ${sshopts[@]} -l root"

function rsync_duts {
    local dirlist="$@"
    ropts=()
    ropts+=( "-e" "$sshcmd" )
    for ipaddr in ${DUT_IPADDR[@]} ; do
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
    
    flows=$(( $flows/4 ))

    if [[ "$flows" -lt 1 ]]; then
        flows=1
    fi
    if [[ "$flows" -gt 64000 ]]; then
        flows=64000
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

# Set Default Settings
SOFTWARE="OVS_TC"
CLOUD_IMAGE_OS="ubuntu"
DPDK_VER="17.11"

# Load Settings from Configuration file
if [ -f $ivg_cfg ]; then
    . $ivg_cfg
fi

# Maintain IVG settings in file
function ivg_update_settings () {
    local varname="$1"
    local value="$2"
    if [ ! -f $ivg_cfg ]; then
        echo "$varname=$value" > $ivg_cfg
    else
        grep -E "^$varname" $ivg_cfg > /dev/null
        if [ $? -eq 0 ]; then
            sed -r 's/^('$varname')=.*$/\1='$value'/' \
                -i $ivg_cfg
        else
            echo "$varname=$value" >> $ivg_cfg
        fi
    fi
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
        DUT_CONNECT=0

    while :; do
        # Set the VM creator path
        VM_MGMT_DIR="\$HOME/IVG_folder/vm_creator/$CLOUD_IMAGE_OS"
        tmux select-pane -t 0
        clear

        #Set Vm Creator path
        VM_MGMT_DIR="\$HOME/IVG_folder/vm_creator/$CLOUD_IMAGE_OS"
        #Set flow count for tests
        flow=$(cat /root/IVG/aovs_2.6B/flow_setting.txt)

        echo "Please choose a option"
        echo ""
        echo -e "O) Toggle between AOVS / OVS_TC \t Setting: $SOFTWARE"
        echo -e "o) Toggle between VM operating systems \t Setting: $CLOUD_IMAGE_OS"
        echo -e "f) Change number of Openflow rules to install: \t Setting: $flow"
        echo ""
        echo "a) Connect to DUT's"
        echo "b) Install/Re-install Agilio-OVS"
        echo "B) Install OVS-TC"
        echo "c) Create backing image for test VM's (Only done once)"
        echo "1) Test Case 1 (Simple ping between hosts)"
        echo "1a)Test Case 1a (Pktgen between hosts)"
        echo "2) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"
        echo "3) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)"
        echo "4) Test case 4 (DPDK-Pktgen Rx -> Ixia Tx SR-IOV)"
        echo "6) Test case 6 (DPDK-pktgen VM-VM uni-directional XVIO)"
        echo "7) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO VXLAN)"
        echo "8) Test Case 8 (DPDK-Pktgen Rx -> Ixia Tx XVIO)"
        echo ""
        echo "10) Test Case 10 (DPDK-pktgen VM-VM uni-directional KOVS VXLAN Intel XL710)"
        echo "11) Test Case 11 (DPDK-pktgen VM-VM uni-directional KOVS Intel XL710)"
        echo "r) Reboot host machines"
        echo "d) Set up DPDK OVS"
        echo "k) Set up KOVS"        
        echo "x) Exit"
        echo ""
        read -p "Enter choice: " OPT

        case "$OPT" in
        
        a)  echo "a) Connect to DUT's"

            dut_ipaddr_config_file="$ivg_config_dir/ipaddr.conf"

            query_dut_ipaddr=""
            if [ -f $dut_ipaddr_config_file ]; then
                echo "Previous DUT IP addresses:"
                cat $dut_ipaddr_config_file
                read -p "Do you want to use previous IP addresses? (y/n) " ans
                case "$ans" in
                    "y"|"yes"|"")
                        . $dut_ipaddr_config_file \
                            || exit -1
                        ;;
                    *) query_dut_ipaddr="yes"
                        ;;
                esac
            else
                query_dut_ipaddr="yes"
            fi

            if [ "$query_dut_ipaddr" == "yes" ]; then
                read -p "Enter DUT1 IP address: " DUT_IPADDR[1]
                read -p "Enter DUT2 IP address: " DUT_IPADDR[2]
                ( \
                    echo "DUT_IPADDR[1]=${DUT_IPADDR[1]}" ; \
                    echo "DUT_IPADDR[2]=${DUT_IPADDR[2]}" ; \
                ) > $dut_ipaddr_config_file
            fi

            export IVG_SERVERS_IPADDR_LIST="${DUT_IPADDR[@]}"

            tmux select-pane -t 0

            # Copy public key to DUTs
            $IVG_dir/helper_scripts/copy_ssh_key.sh ${DUT_IPADDR[@]}

            # Start interactive SSH session in TMUX window

            tmux_run_cmd DUT1 "ssh ${sshopts[@]} ${DUT_IPADDR[1]}"
            tmux_run_cmd DUT2 "ssh ${sshopts[@]} ${DUT_IPADDR[2]}"

            # Print 'CONNECTED'
            tmux_run_cmd ALL "/bin/echo -e '\x43\x4f\x4e\x4e\x45\x43\x54\x45\x44'"

            wait_text ALL "CONNECTED"

            tmux_run_cmd ALL "mkdir -p \$HOME/IVG_folder"
            tmux_run_cmd ALL "export IVG_dir=\$HOME/IVG_folder"

            rsync_duts \
                $IVG_dir/helper_scripts \
                $IVG_dir/aovs_2.6B/vm_creator \
                || exit -1

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/setup-dut.sh"

            wait_text ALL "DONE(setup-dut.sh)"

            echo " - Collect System Inventory logs from DUTs"
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/inventory.log \
                $capdir/inventory-DUT1-${DUT_IPADDR[1]}.log \
                || exit -1
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/inventory.log \
                $capdir/inventory-DUT2-${DUT_IPADDR[2]}.log \
                || exit -1

            echo 64000 > $IVG_dir/aovs_2.6B/flow_setting.txt

            for ipaddr in ${DUT_IPADDR[@]} ; do
                scp ${sshopts[@]} $IVG_dir/aovs_2.6B/flow_setting.txt \
                    root@$ipaddr:/root/IVG_folder/aovs_2.6B \
                    || exit -1
            done

            DUT_CONNECT=1

            ;;

        b)  echo "b) Install/Re-install Agilio-OVS"
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Installation_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Installation_DUT_2.log" C-m           

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
               
                scp ${sshopts[@]} $LATEST_AOVS root@${DUT_IPADDR[1]}:/root
                scp ${sshopts[@]} $LATEST_AOVS root@${DUT_IPADDR[2]}:/root

                tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/configure_grub.sh" C-m
                tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/configure_grub.sh" C-m
    
                wait_text ALL "Grub updated"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Installation_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Installation_DUT_2.log $capdir

            ;;

        B)  echo "B) Install OVS-TC"
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi
            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/install-ovs-tc.sh $DPDK_VER" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/install-ovs-tc.sh $DPDK_VER" C-m

            wait_text ALL "DONE(install-ovs-tc.sh)"

            ;;

        c)  echo "c) Create backing image for test VM's (Only needed once)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/install_pre_req.sh"

            wait_text ALL "PreReq Installed!"

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_2.log" C-m

            # Copy VM creator script to DUT
            rsync_duts \
                $IVG_dir/aovs_2.6B/vm_creator \
                || exit -1

            # Download cloud image to local machine and update DUTs
            export CLOUD_IMAGE_OS
            $IVG_dir/helper_scripts/download_cloud_image.sh \
                || exit -1

            # Create backing image
            tmux_run_cmd ALL "$VM_MGMT_DIR/x_create_backing_image.sh"

            echo -e "${GREEN}Creating base image for test VM's, please wait...${NC}"

            wait_text ALL "Base image created!"

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux_run_cmd ALL "exit"

            sleep 1
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Backing_image_DUT_2.log $capdir

            ;;

        1)  echo "1) Test Case 1 (Simple ping between hosts)"
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_2.log" C-m
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_1_ping \
                || exit -1

            # Setup test case 1
            tmux send-keys -t 2 "./IVG_folder/test_case_1_ping/setup_test_case_1.sh -i 10.0.0.1 -s $SOFTWARE" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1_ping/setup_test_case_1.sh -i 10.0.0.2 -s $SOFTWARE" C-m

            echo -e "${GREEN}* Setting up test case 1${NC}"
            
            # Wait for test case 1 setup to complete
            wait_text ALL "DONE(setup_test_case_1.sh)"

            echo -e "${GREEN}* Running test case 1 - Simple ping${NC}"

            #Ping form one host
            tmux send-keys -t 2 "ping 10.0.0.2 -c 5" C-m

            sleep 6

            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m
            sleep 1
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_2.log $capdir

            ;;

        1a) echo "1) Test Case 1 (Simple ping between hosts)"
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_1_DUT_2.log" C-m
            
            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            ##############################################
            # BIFF

            echo -e "${GREEN}* Setting up BIFF 1${NC}"

            /root/IVG/helper_scripts/biff_setup.sh ${DUT_IPADDR[2]}
            ##############################################


            # Copy test case scripts to DUT's
            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_1a_pktgen \
                || exit -1

            #Setup test case 1
            tmux send-keys -t 2 "./IVG_folder/test_case_1a_pktgen/setup_test_case_1a.sh -s $SOFTWARE" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_1a_pktgen/setup_test_case_1a.sh -s $SOFTWARE" C-m

            echo -e "${GREEN}* Setting up test case 1${NC}"
            
            #Wait for test case 1 setup to complete
            wait_text ALL "DONE(setup_test_case_1a.sh)"

            NUMA=$(lscpu | grep NUMA | head -1 | sed 's/.*\([0-9]\)/\1/g')
            echo $NUMA
            MEM=""
            NUM=$(cat $(find / -name "*run_dpdk-pktgen_uni-tx*" | head -1) | grep socket-mem | sed -r 's#^[^0-9]*([0-9]+).*#\1#')
            echo $NUM
            for i in $(seq 1 $NUMA)
            do 
                MEM="$MEM$NUM,"
            done
            MEM=${MEM::-1}
            echo $MEM

            tmux send-keys -t 2 'sed -i "s/^memory=.*/memory=\"--socket-mem '$MEM'\"/g" /root/IVG_folder/vm_creator/ubuntu/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/0_run_dpdk-pktgen_uni-rx.sh' C-m
            tmux send-keys -t 2 'sed -i "s/^memory=.*/memory=\"--socket-mem '$MEM'\"/g" /root/IVG_folder/vm_creator/ubuntu/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/1_run_dpdk-pktgen_uni-tx.sh' C-m
            tmux send-keys -t 3 'sed -i "s/^memory=.*/memory=\"--socket-mem '$MEM'\"/g" /root/IVG_folder/vm_creator/ubuntu/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/0_run_dpdk-pktgen_uni-rx.sh' C-m
            tmux send-keys -t 3 'sed -i "s/^memory=.*/memory=\"--socket-mem '$MEM'\"/g" /root/IVG_folder/vm_creator/ubuntu/vm_scripts/samples/DPDK-pktgen/3_dpdk_pktgen_lua_capture/1_run_dpdk-pktgen_uni-tx.sh' C-m
 

            sleep 1
            tmux send-keys -t 2 "cd /root/IVG_folder/vm_creator/ubuntu/vm_scripts/samples/DPDK-pktgen" C-m
            tmux send-keys -t 3 "cd /root/IVG_folder/vm_creator/ubuntu/vm_scripts/samples/DPDK-pktgen" C-m

            tmux send-keys -t 2 "./1_configure_hugepages.sh" C-m
            tmux send-keys -t 3 "./1_configure_hugepages.sh" C-m

            sleep 1

            tmux send-keys -t 2 "cd 3_dpdk_pktgen_lua_capture" C-m
            tmux send-keys -t 3 "cd 3_dpdk_pktgen_lua_capture" C-m

            tmux send-keys -t 3 "./0_run_dpdk-pktgen_uni-rx.sh" C-m
            sleep 5
            tmux send-keys -t 2 "./1_run_dpdk-pktgen_uni-tx.sh n" C-m


            echo -e "${GREEN}* Running test case 1a - Host pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"

            sleep 2
            cp /root/capture.txt $script_dir
            cp /root/parsed_data.txt $script_dir
            sleep 2

            if [[ ! -e "parsed_data.txt" ]]; then
                mv parsed_data.txt "Host_pktgen_test_run_parsed-0-f$flow_count.txt"
            else
                num=1
                while [[ -e "Host_pktgen_test_run_parsed-$num-f*.txt" ]]; do
                    (( num++ ))
                done
                mv parsed_data.txt "Host_pktgenV_test_run_parsed-$num-f$flow_count.txt" 
            fi

            if [[ ! -e "capture.txt" ]]; then
                mv capture.txt "Host_pktgen_test_run-0-f$flow_count.txt"
            else
                num=1
                while [[ -e "Host_pktgen_test_run-$num-f*.txt" ]]; do
                    (( num++ ))
                done
                mv capture.txt "Host_pktgen_test_run-$num-f$flow_count.txt" 
            fi
            
            #_#_#_#_#_END LOG_#_#_#_#_#
            tmux send-keys -t 3 "exit" C-m
            tmux send-keys -t 2 "exit" C-m

            sleep 1

            # CLEAN
            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m

            ;;

        2)  echo "2) Test Case 2 (DPDK-pktgen VM-VM uni-directional SR-IOV)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_2.log" C-m            

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME="netronome-sriov-vm"
            VM_CPUS=5
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            # Copy test-case scripts to DUTs
            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_2_sriov_uni \
                || exit -1

            tmux send-keys -t 2 "./IVG_folder/test_case_2_sriov_uni/1_port/setup_test_case_2.sh $VM_BASE_NAME $VM_CPUS $SOFTWARE" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_2_sriov_uni/1_port/setup_test_case_2.sh $VM_BASE_NAME $VM_CPUS $SOFTWARE" C-m
            
            echo -e "${GREEN}* Setting up test case 2${NC}"

            wait_text ALL "DONE(setup_test_case_2.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            # Pause tmux until VM boots up 
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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_2
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_2

            echo -e "${GREEN}* Running test case 2 - SRIOV DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            #flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} 'ovs-dpctl show | grep flows: | cut -d ':' -f2')
            flow_count=$flow

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_2

            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_2.csv $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_2.html $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_2_DUT_2.log $capdir

            # CLEAN
            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m

            ;;

        3)  echo "3) Test Case 3 (DPDK-pktgen VM-VM uni-directional SR-IOV VXLAN)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi
             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_2.log" C-m
            


            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME="netronome-sriov-vxlan-vm"
            VM_CPUS=5
            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.1"

            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            rsync_duts \
                $IVG_dir/helper_scripts \
                $IVG_dir/aovs_2.6B/test_case_3_sriov_vxlan_uni \
                || exit -1

            tmux send-keys -t 2 "./IVG_folder/test_case_3_sriov_vxlan_uni/1_port/setup_test_case_3.sh $VM_BASE_NAME $VM_CPUS $DST_IP $SRC_IP $SOFTWARE" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_3_sriov_vxlan_uni/1_port/setup_test_case_3.sh $VM_BASE_NAME $VM_CPUS $SRC_IP $DST_IP $SOFTWARE" C-m
            
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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_3
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_3
            
            echo -e "${GREEN}* Running test case 3 - SRIOV VXLAN DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            #flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} 'ovs-dpctl show | grep flows: | cut -d ':' -f2')
            flow_count=$flow


            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_3

            #Run data parser
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"

            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m

            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_3.csv $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_3.html $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_3_flow_count.txt $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_3_DUT_2.log $capdir

            # CLEAN
            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m

            ;;

         4)  echo "4) Test case 4 (DPDK-Pktgen Rx -> Ixia Tx SR-IOV)"
            
            ;;
                
         5)  echo "5) Test case 5 (Ixia Tx & Rx - VM L2FWD SR-IOV)"

            ;;

         6)  echo "6) Test Case 6 (DPDK-pktgen VM-VM uni-directional XVIO)"
            
            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_2.log" C-m

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME=netronome-xvio-vm
            VM_CPUS=5
            XVIO_CPUS=2
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_6_xvio_uni \
                || exit -1

            tmux send-keys -t 2 "./IVG_folder/test_case_6_xvio_uni/1_port/setup_test_case_6.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS $SOFTWARE" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_6_xvio_uni/1_port/setup_test_case_6.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS $SOFTWARE" C-m
            
            echo -e "${GREEN}* Setting up test case 6${NC}"
            wait_text ALL "DONE(setup_test_case_6.sh)"

            tmux send-keys -t 2 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/start_vm.sh $VM_BASE_NAME" C-m
        
            # Wait for VMs to boot up
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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_6
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_6
            
            echo -e "${GREEN}* Running test case 6 - XVIO DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            #flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} "ovs-dpctl show | grep flows: | cut -d ':' -f2 | cut -d ' ' -f2" )
            flow_count=$flow
            echo "FLOW_COUNT: $flow_count"

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_6

            #Run data parser
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"
            
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            sleep 1
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            sleep 1
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_6.csv $script_dir
            sleep 1
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_6.html $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_6_DUT_2.log $capdir

            sleep 5

            # CLEAN
            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m

            ;;


        7)  echo "7) Test Case 7 (DPDK-pktgen VM-VM uni-directional XVIO - VXLAN)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_2.log" C-m

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            rsync_duts \
                $IVG_dir/helper_scripts \
                || exit -1

            VM_BASE_NAME="netronome-xvio-vxlan-vm"
            VM_CPUS=5
            XVIO_CPUS=2
            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.3"

            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_7_xvio_vxlan_uni \
                || exit -1

            tmux send-keys -t 2 "./IVG_folder/test_case_7_xvio_vxlan_uni/1_port/setup_test_case_7.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS $DST_IP $SRC_IP $SOFTWARE" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_7_xvio_vxlan_uni/1_port/setup_test_case_7.sh $VM_BASE_NAME $VM_CPUS $XVIO_CPUS $SRC_IP $DST_IP $SOFTWARE" C-m
            
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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_7
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_7
            

            echo -e "${GREEN}* Running test case 7 - XVIO VXLAN DPDK-pktgen${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            #flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} 'ovs-dpctl show | grep flows: | cut -d ':' -f2')
            flow_count=$flow

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_7

            #Run data parser
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"
            
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_7.csv $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_7.html $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_7_flow_count.txt $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_7_DUT_2.log $capdir

            sleep 2 

            # CLEAN
            tmux send-keys -t 2 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m
            tmux send-keys -t 3 "/root/IVG_folder/helper_scripts/stop_ovs-tc.sh" C-m


            ;;

        8)  echo "8) Test Case 8 (DPDK-pktgen VM-VM bi-directional SR-IOV)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_8_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_8_DUT_2.log $capdir

            ;;


        10)  echo "10) Test Case 10 (DPDK-pktgen VM-Vm uni-directional KOVS VXLAN Intel XL710)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_2.log" C-m

            DST_IP="10.10.10.2"
            SRC_IP="10.10.10.1"

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME=netronome-kovs-vxlan-intel-vm
            VM_CPUS=4
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_10_kovs_vxlan_uni_intel \
                || exit -1

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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_10
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_10
            

            echo -e "${GREEN}* Running test case 10 - DPDK-Pktgen KOVS VXLAN Intel XL710${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_10
            
            
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_10.csv $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_10.html $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_10_flow_count.txt $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_10_DUT_2.log $capdir
            ;;

         11)  echo "11) Test Case 11 (DPDK-pktgen VM-VM uni-directional KOVS Intel XL710)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_2.log" C-m

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME="netronome-kovs-intel-vm"
            VM_CPUS=4
            
            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_11_kovs_uni_intel \
                || exit -1

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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_11
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_11
            

            echo -e "${GREEN}* Running test case 11 - DPDK-Pktgen KOVS Intel XL710${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_11
            
            
            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_11.csv $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_11.html $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_11_flow_count.txt $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_11_DUT_2.log $capdir
            ;;
    
         12)  echo "12) Test Case 12 (DPDK-pktgen VM-VM uni-directional DPDK OVS Intel XL710)"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

             #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_2.log" C-m

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            VM_BASE_NAME=netronome-dpdk-ovs-intel-vm
            VM_CPUS=4

            echo -e "${GREEN}* VM's are called $VM_BASE_NAME${NC}"
            tmux send-keys -t 2 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            tmux send-keys -t 3 "$VM_MGMT_DIR/y_create_vm_from_backing.sh $VM_BASE_NAME" C-m
            
            echo -e "${GREEN}* Creating test VM from backing image${NC}"
            wait_text ALL "VM has been created!"

            rsync_duts \
                $IVG_dir/aovs_2.6B/test_case_12_dpdk_ovs_uni_intel \
                || exit -1

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
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-measure.sh test_case_12
            ssh -tt ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-screenshot.sh test_case_12
            

            echo -e "${GREEN}* Running test case 11 - DPDK-Pktgen KOVS Intel XL710${NC}"
            sleep 5
            wait_text 3 "Test run complete"

            # Ouput flow count to text file
            flow_count=$(ssh ${sshopts[@]} ${DUT_IPADDR[2]} 'ovs-dpctl show | grep flows: | cut -d ':' -f2')

            #CPU meas end
            echo -e "${GREEN}* Stopping CPU measurement${NC}"
            ssh ${sshopts[@]} ${DUT_IPADDR[2]} /root/IVG_folder/helper_scripts/cpu-parse-copy-data.sh test_case_12

            tmux send-keys -t 3 "./parse_and_plot.py" C-m
            wait_text 3 "Data parse complete!"
            sleep 1
            tmux send-keys -t 2 "exit" C-m
            tmux send-keys -t 3 "exit" C-m
            
            echo -e "${GREEN}* Copying data...${NC}"
            sleep 1
            tmux send-keys -t 3 "./IVG_folder/helper_scripts/x_copy_data_dump.sh $VM_BASE_NAME" C-m
            
            sleep 2
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/capture.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/parsed_data.txt $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_12.csv $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_12.html $script_dir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/test_case_12_flow_count.txt $script_dir

            tmux_run_cmd ALL "\$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown"
            wait_text ALL "DONE(delete-vms.sh)"

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Test_case_12_DUT_2.log $capdir
            ;;

        o)  echo "o) Toggle VM OS"

            case "$CLOUD_IMAGE_OS" in
                "ubuntu") CLOUD_IMAGE_OS="centos" ;;
                "centos") CLOUD_IMAGE_OS="ubuntu" ;;
            esac

            ivg_update_settings "CLOUD_IMAGE_OS" "$CLOUD_IMAGE_OS"

            ;;

        O)  echo "O) Toggle Host Software"

            case "$SOFTWARE" in
                "OVS_TC") SOFTWARE="AOVS" ;;
                "AOVS") SOFTWARE="OVS_TC" ;;
                "None") SOFTWARE="OVS_TC" ;;
            esac

            ivg_update_settings "SOFTWARE" "$SOFTWARE"

            ;;

        k)  echo "k) Setup KOVS"

            if [ $DUT_CONNECT == 0 ]; then
                echo -e "${RED}Please connect to DUT's first${NC}"
                sleep 5
                continue
            fi

            #_#_#_#_#_START LOG_#_#_#_#_#
            tmux send-keys -t 2 "script /root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_1.log" C-m
            tmux send-keys -t 3 "script /root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_2.log" C-m

            tmux send-keys -t 3 "cd" C-m
            tmux send-keys -t 2 "cd" C-m

            rsync_duts \
                $IVG_dir/helper_scripts \
                $IVG_dir/aovs_2.6B/test_case_10_kovs_vxlan_uni_intel \
                || exit -1

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Setup_KOVS_DUT_2.log $capdir

            ;;

        d)  echo "d) Setup DPDK OVS"
            DPDK_VER=dpdk-17.05
            OVS_VER=openvswitch-2.8.1

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

            rsync_duts \
                $IVG_dir/helper_scripts \
                $IVG_dir/aovs_2.6B/test_case_12_dpdk_ovs_uni_intel  \
                || exit -1
            tmux send-keys -t 2 "./IVG_folder/test_case_12_dpdk_ovs_uni_intel/setup_test_case_install_12.sh $DPDK_VER $OVS_VER" C-m
            tmux send-keys -t 3 "./IVG_folder/test_case_12_dpdk_ovs_uni_intel/setup_test_case_install_12.sh $DPDK_VER $OVS_VER" C-m

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
            scp ${sshopts[@]} root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/logs/Setup_DPDK_OVS_DUT_1.log $capdir
            scp ${sshopts[@]} root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/logs/Setup_DPDK_OVS_DUT_2.log $capdir

            ;;	


        f)  echo "f) Set amount of flows" 
            read -p "Enter amount of flows for next test: " FLOW_COUNT
        
            echo $FLOW_COUNT > /root/IVG/aovs_2.6B/flow_setting.txt
            sleep 1
            scp ${sshopts[@]} /root/IVG/aovs_2.6B/flow_setting.txt root@${DUT_IPADDR[1]}:/root/IVG_folder/aovs_2.6B/
            scp ${sshopts[@]} /root/IVG/aovs_2.6B/flow_setting.txt root@${DUT_IPADDR[2]}:/root/IVG_folder/aovs_2.6B/
            sleep 1
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
                ip=${DUT_IPADDR[1]}
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


