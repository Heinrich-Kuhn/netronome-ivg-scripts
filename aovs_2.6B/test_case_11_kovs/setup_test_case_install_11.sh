#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

$script_dir/0_uninstall_aovs.sh
$script_dir/1_install_prerequisitions.sh
$script_dir/2_install_kovs.sh

if [ $? == 1 ]; then 
echo "Could not install KOVS"
exit -1
fi

$script_dir/3_install_intel.sh

if [ $? == 1 ]; then 
echo "Could not install Intel driver"
exit -1
fi

echo "DONE(setup_test_case_11_install.sh)"

exit 0

