#!/bin/bash

echo 
echo "enabling LLDP on virbr* bridges"
echo
brctl show | grep -v "bridge name" | awk '{ if ($1 ~ /virbr/) print $1}' | grep -v -- "-nic" | while read a; do 
	echo settings 0x4000 for bridge $a
	echo 16384 > /sys/class/net/${a}/bridge/group_fwd_mask
done
