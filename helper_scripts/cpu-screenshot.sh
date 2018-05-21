#!/bin/bash

file_name=$1
sleep 10
echo q | htop | aha --black --line-fix > /root/IVG_folder/${file_name}.html
