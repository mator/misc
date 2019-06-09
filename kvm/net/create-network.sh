#!/bin/bash

if [ "$1" == "" ]; then
	echo "error: no network name specified"
	exit 1
fi

networkname="$1"
networkfile=`mktemp`

sed "s/netname/$networkname/" net-template.xml > $networkfile

virsh net-define $networkfile
rm $networkfile
virsh net-autostart $networkname
virsh net-start $networkname


echo
echo ===
echo "don't forget to run ./enable-lldp-on-bridges.sh (and set-mtu on new vnics) on kvm"
echo ===
