#!/bin/bash

git clone https://github.com/emmericp/MoonGen.git
cd MoonGen
git submodule update --init
./build.sh
