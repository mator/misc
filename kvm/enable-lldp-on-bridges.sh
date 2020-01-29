#!/bin/bash

#value=65535 # no restriction
value=0x4000 # lldp
echo 
echo "enabling LLDP on virbr* bridges"
echo
brctl show | grep -v "bridge name" | awk '{ if ($1 ~ /virbr/) print $1}' | grep -v -- "-nic" | while read a; do 
	echo settings $value for bridge $a
	echo $value > /sys/class/net/${a}/bridge/group_fwd_mask
done
