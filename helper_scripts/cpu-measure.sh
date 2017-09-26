#!/bin/bash

file_name=$1
mpstat 2 > /tmp/${file_name} &
exit 0
