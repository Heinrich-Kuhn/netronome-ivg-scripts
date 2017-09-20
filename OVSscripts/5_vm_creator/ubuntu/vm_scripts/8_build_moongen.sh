#!/bin/bash

git clone https://github.com/emmericp/MoonGen.git
cd MoonGen
git submodule update --init
./build.sh

apt-get -y install cloud-init 
