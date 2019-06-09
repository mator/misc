#!/bin/bash

#
# i wanted to put "over 9000!!!" meme here, but passed on this one
#

# used with libvirt (virsh -V) version below 3.1
# https://libvirt.org/formatnetwork.html
# starting from 3.1 you can specify xml element name <mtu size=9000>
# in network definition

echo 
echo setting 9000 mtu size for all virtual NICs
echo
#brctl show | grep -v "bridge name" | awk '{ if ($1 ~ /virbr/) print $1}' | grep -v -- "-nic" | while read a; do 
#	echo settings 0x4000 for bridge $a
#done

b=""
bridge link show | awk ' $10 ~ /virbr/ {print $2 , $10} ' | sort -b -k2 | while read vnic vbridge; do

    if [ "$b" != "$vbridge" ]; then
        echo "setting vnics on $vbridge"
        b=$vbridge
    fi

    ip link set dev $vnic mtu 9000

done
