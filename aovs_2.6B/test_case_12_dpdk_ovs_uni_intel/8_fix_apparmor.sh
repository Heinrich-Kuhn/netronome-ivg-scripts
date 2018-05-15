#!/bin/bash
service apparmor stop
service apparmor teardown
service libvirt-bin restart
