#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

echo $script_dir | sed 's/\(IVG\).*/\1/g'

echo $script_dir


