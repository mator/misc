#!/usr/bin/bash

filler="N/A"

VLANs="3 5 55 62 702 1311 1316 1324 1330 1353 1355 1395 1393 1455 1465"

# print header or not
# values is 1 or any other
pheader=0 

# debug function, used to check values in runtime, outputs on stderr (file desc 2)
function echoerr() { echo "$@" 1>&2; }

function LPAR_tab1() {

	[ $pheader -eq 1 ] && echo -e "LPAR\t VG\t Conc_Capable\t LV/FS_Name\t LV_type\t INTER-POLICY\t PP_Size_(MB)\t MOUNT\t Mount_options\t FS_type\tFS_size_(MB)\t Block_size_(bytes)\t Auto_mount"

	local vg vg_type vg_conc_cap vg_ppsize vg_ppdist lv lvtype lvinterpol fs fssize
	local fstypeauto fstype fsauto fsoptions fsblocksize 

	lsvg | while read vg; do

		vg_type=$filler
		vg_conc_cap=$(lsattr -El $vg | awk '/conc_capable/ {print $2}')
		vg_ppsize=$(lsvg $vg | awk '/PP SIZE/ {print $6}')
		vg_ppdist=$filler

		# lvtype in cluster configurations can be NULL, so we check numbers of records (NF) in awk, to make sure we get right information
		lsvg -l $vg | sed 1,2d | awk '{ if (NF==7) {print $1,"\t",$2,"\t",$7} else {print $1,"\t'$filler'\t",$6} }' | while read lv lvtype fs; do

			fssize=$(getconf DISK_SIZE "/dev/$lv")
			lvinterpol=$(lslv $lv | awk '/INTER-POLICY/ {print $2}')

			if [ "$fs" != "N/A" ]; then

				fstypeauto=$(lsfs $fs | awk '/dev/ {print $4,$7,$6}')
				fstype=$(echo $fstypeauto | cut -f1 -d' ')
				fsauto=$(echo $fstypeauto | cut -f2 -d' ')
				fsoptions=$(echo $fstypeauto | cut -f3 -d' ')

				fsblocksize=$(lsfs -q $fs | awk -F, '/block size/ {print $3}' | cut -f4 -d' ')

			else 
				fstype=$filler
				fsauto=$filler
				fsoptions=$filler
				fsblocksize=$filler
			fi 

			echo -e "$HOST\t $vg\t $vg_conc_cap\t $lv\t $lvtype\t $lvinterpol\t $vg_ppsize\t $fs\t $fsoptions\t $fstype\t $fssize\t $fsblocksize\t $fsauto"
		done

	done

	return 0
}

function LPAR_tab2 {

	local CLRN='EMC CLARiiON'
	local SYMX='EMC Symmetrix'
	local STWZ='IBM 2076'
	local HPXP='XP MPIO Disk'
	local DASD='SAS Disk Drive'
	local VIRT='Virtual SCSI Disk'
	local Host=$(hostname)
	local Lun Serial Node Uid Fru Ploc
	
	
	local hdisk hdiskid vg hd_active hd_size out1 hd_status
	local hd_maxtransfer hd_qdepth hd_rpol hd_algo hd_type
	local hd_hcheck_cmd hd_hcheck_int hd_hcheck_mod
	
	[ $pheader -eq 1 ] && echo -e "LPAR\t HDISK\t Status\t SIZE\t VG\t PVID\t max_transfer\t q_depth\t res_policy\t algo\t hcheck_cmd\t hcheck_int\t hcheck_mode\t Serial\t Lun\t Node\t Uid\t FRU\t PLOC\t Description"
	
	lspv | while read hdisk hdiskid vg hd_active; do

		Lun=$filler
		Serial=$filler
		Node=$filler
		Uid=$filler
		Fru=$filler
		Ploc=$filler
		
		hd_status=$(lsdev -l $hdisk -F "status")
		
		local Hdisk=$hdisk
		# additional grep to remove following error:
		# 0519-004 libodm: The specified search criteria is incorrectly formed.
		hd_type=$(lscfg -l $hdisk | grep $hdisk | while read str1 str2 str3; do echo $str3; done)			
		if echo $hd_type | grep "$CLRN" 1>/dev/null 
		then 
			Serial=$(lscfg -vpl ${Hdisk} | grep Serial | cut -c 37-)
			#Size=$(bootinfo -s ${Hdisk})
			Lun=$(lscfg -vpl ${Hdisk} | grep FRU |cut -c 37-)
			#Desc=$(lscfg -vpsl ${Hdisk} | head -n 2 | tail -n 1 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}')
			#echo "HOST=${Host} PV=${Hdisk} SN=${Serial} LUN=${Lun} SIZE=${Size} ${Desc}" 
		elif echo $hd_type | grep "$SYMX" 1>/dev/null 
		then 
			Serial=$(lscfg -vpl ${Hdisk} | grep 'EC Level' | cut -c 37-)
			#Size=$(bootinfo -s ${Hdisk})
			Lun=$(lscfg -vpl ${Hdisk} | grep 'LIC Node VPD' |cut -c 37-)
			#Desc=$(lscfg -vpsl ${Hdisk} | head -n 2 | tail -n 1 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}')
			#echo "HOST=${Host} PV=${Hdisk} SN=${Serial} LUN=${Lun} SIZE=${Size} ${Desc}" 
		elif echo $hd_type | grep "$STWZ" 1>/dev/null 
		then 
			Node=$(lsattr -El ${Hdisk} -a node_name | awk '{print $2}' | cut -c 3-)
			#Size=$(bootinfo -s ${Hdisk})
			Uid=$(lsattr -El ${Hdisk} -a unique_id | awk '{print $2}' | cut -c 6-37)
			#Desc=$(lscfg -vpsl ${Hdisk} | head -n 2 | tail -n 1 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}')
			#echo "HOST=${Host} PV=${Hdisk} NODE=${Node} UID=${Uid} SIZE=${Size} ${Desc}" 
		elif echo $hd_type | grep "$HPXP" 1>/dev/null 
		then 
			Serial=$(lscfg -vpl ${Hdisk} | grep 'Serial Number' | awk '{print $3}')
			Lun=$(lscfg -vpl ${Hdisk} | grep '(Z1)' | awk '{print $2}' | cut -c 22-)
			#Size=$(bootinfo -s ${Hdisk})
			#Desc=$(lscfg -vpsl ${Hdisk} | head -n 2 | tail -n 1 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}')
			#echo "HOST=${Host} PV=${Hdisk} SN=${Serial} LUN=${Lun} SIZE=${Size} ${Desc}" 
		elif echo $hd_type | grep "$DASD" 1>/dev/null 
		then 
			Fru=$(lscfg -vpl ${Hdisk} | grep 'FRU Number' | awk '{print $2}' | cut -c 25-)
			Ploc=$(lscfg -vpsl ${Hdisk} | head -n 1 | awk '{print $2}')
			#Size=$(bootinfo -s ${Hdisk})
			#Desc=$(lscfg -vpsl ${Hdisk} | head -n 2 | tail -n 1 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}')
			#echo "HOST=${Host} PV=${Hdisk} FRU=${Fru} PLOC=${Ploc} SIZE=${Size} ${Desc}" 
#		elif echo $hd_type | grep "$VIRT" 1>/dev/null 
#		then 
			#Ploc=$(lscfg -vpsl ${Hdisk} | head -n 1 | awk '{print $2}')
			#Size=$(bootinfo -s ${Hdisk})
			#Desc=$(lscfg -vpsl ${Hdisk} | head -n 2 | tail -n 1 | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}')
			#echo "HOST=${Host} PV=${Hdisk} PLOC=${Ploc} SIZE=${Size} ${Desc}" 
		fi
	
		hd_size=$(getconf DISK_SIZE /dev/$hdisk)
		echo -en "$HOST\t $hdisk\t$hd_status\t$hd_size\t $vg\t $hdiskid\t "

		out1=$(lsattr -El $hdisk)

		hd_maxtransfer=$(echo "$out1" | awk '/max_transfer/ {print $2}')
		hd_qdepth=$(echo "$out1" | awk '/queue_depth/ {print $2}')
		hd_rpol=$(echo "$out1" | awk '/reserve_policy/ {print $2}')
		hd_algo=$(echo "$out1" | awk '/algorithm/ {print $2}')
		hd_hcheck_cmd=$(echo "$out1" | awk '/hcheck_cmd/ {print $2}')
		hd_hcheck_int=$(echo "$out1" | awk '/hcheck_interval/ {print $2}')
		hd_hcheck_mod=$(echo "$out1" | awk '/hcheck_mode/ {print $2}')

		[ "x$hd_hcheck_cmd" == "x" ] && hd_hcheck_cmd=$filler
		[ "x$hd_hcheck_int" == "x" ] && hd_hcheck_int=$filler
		[ "x$hd_hcheck_mod" == "x" ] && hd_hcheck_mod=$filler
		[ "x$hd_maxtransfer" == "x" ] && hd_maxtransfer=$filler

		echo -ne "$hd_maxtransfer\t $hd_qdepth\t $hd_rpol\t $hd_algo\t $hd_hcheck_cmd\t $hd_hcheck_int\t $hd_hcheck_mod\t"
		# local Lun Serial Node Uid Fru Ploc
		echo -e "$Serial\t $Lun\t $Node\t $Uid\t $Fru\t $Ploc\t $hd_type"

	done

	return 0
}

function LPAR_tab3 {

	[ $pheader -eq 1 ] && echo -e "LPAR\t adapter\t status\t max_xfer_sz\t num_cmd_elems\t scsi_device\t err_recovery\t dyntrk\t link_speed\t total_queue_depth\t scsi_id\t wwn"

	local a_name out1
	local a_maxfer a_numcmd a_scsidev a_fscsidev a_dyntrk a_linkspeed a_scsiid a_wwn a_fcerrr a_queue
	local a_status
	


	# (lsdev -Cc adapter -l fcs* -F name; lsdev -Cc adapter -l vscsi* -F name) | cat -
	lsdev -Cc adapter -F "name status" | egrep "^(fcs|vscsi)" | while read a_name a_status; 
	do
		# fillers of N/A attributes for adapters
		a_maxfer=$filler
		a_numcmd=$filler
		a_scsidev=$filler
		a_fscsidev=$filler	
		a_dyntrk=$filler
		a_linkspeed=$filler
		a_scsiid=$filler
		a_wwn=$filler
		a_fcerrr=$filler
		a_queue=$filler
		# first 3 characters of adapter name from "fcsX" or "vscsiX"
		case "$(echo $a_name | cut -c1-3)" in

			fcs ) 	
				if [ "$a_status" == "Available" ]; then
					out1=$(lsattr -El $a_name)
					a_maxfer=$(echo "$out1" | awk '/max_xfer_size/ {print $2}')
					a_numcmd=$(echo "$out1" | awk '/num_cmd_elems/ {print $2}')

					[ "x$a_maxfer" == "x" ] && a_maxfer=$filler
					[ "x$a_numcmd" == "x" ] && a_numcmd=$filler

					# child fscsiX and its attributes (beware of fetching fcnet*, so we're implicitly specify -l fscsi*)
					a_fscsidev=$(lsdev -p $a_name -l fscsi\* -F name)

					out1=$(lsattr -El $a_fscsidev -F "attribute value")
					a_fcerrr=$(echo "$out1" | awk '/fc_err_rec/ {print $2}')
					a_dyntrk=$(echo "$out1" | awk '/dyntrk/ {print $2}')
					a_scsiid=$(echo "$out1" | awk '/scsi_id/ {print $2}')
					[ "x$a_scsiid" == "x" ] && a_scsiid=$filler
					

					# link speed
					# we use 2 different methods to get link speed
					# first works for physical machines, link speed is taken from adapter attributes via lsattr
					# second works for LPARs, link speed is taken from fcstat
					a_linkspeed=$(echo "$out1" | awk '/link_speed/ {print $2}')
					if [ "x$a_linkspeed" == "x" ]; then
						# fallback to LPAR
						if [ "$a_scsiid" == "$filler" ]; then
							a_linkspeed=$filler
						else 
							a_linkspeed=$(fcstat $a_name | awk -F: '/Port Speed \(running\)/ {print $2}' | tr -d " " | sed 's/BIT//')	
						fi
					fi

					# queue depth, taken from corresponding fcsX -> fscsiX adapters
					# query fscsiX to fetch child disks and their attributes
					a_queue=$(lspath -p $a_fscsidev -F name | sort | uniq | while read hdisk; do 
						lsattr -El $hdisk -a queue_depth -F value; 
					done | awk '{ sum += $1 } END { print sum }')
					[ "x$a_queue" == "x" ] && a_queue=$filler

					a_wwn=$(lscfg -vpl $a_name | grep "Network Address" | sed 's#\.# #g' | awk '{print $3}')
				fi
				
				echo -e "$HOST\t $a_name\t $a_status\t $a_maxfer\t $a_numcmd\t $a_fscsidev\t $a_fcerrr\t $a_dyntrk\t $a_linkspeed\t $a_queue\t $a_scsiid\t $a_wwn"
				;;

			vsc ) 
				# the only 2 attributes for vscsiX adapters is vscsi_err_recov and queue depth
				a_vscsie=$(lsattr -El $a_name | awk '/vscsi_err_recov/ {print $2}')
				if [ "$a_status" == "Available" ]; then
					# queue depth
					# 
					a_queue=$(lspath -p $a_name -F name | sort | uniq | while read hdisk; do 
						lsattr -El $hdisk -a queue_depth -F value; 
					done | awk '{ sum += $1 } END { print sum }')
					[ "x$a_queue" == "x" ] && a_queue=0
				fi

				#printf "%-10s %10s %10s %10s %10s %10s\n" $a_name $a_maxfer $a_numcmd $a_scsidev $a_vscsie $a_dyntrk
				echo -e "$HOST\t $a_name\t $a_status\t $a_maxfer\t $a_numcmd\t $a_scsidev\t $a_vscsie\t $a_dyntrk\t $a_linkspeed\t $a_queue\t $a_scsiid\t $a_wwn"
				;;

			*) ;;
		esac

	done

	return 0
}

function LPAR_tab4 {

	local f_header="%-20s\t%-15s\t%10s\t%10s\t%10s\t%33s\t%10s\t%20s\t%10s\n"
	[ $pheader -eq 1 ] && printf "$f_header" LPAR HDISK Status parent PathID connection priority node_name scsi_id

	local out1 a_pri a_nodename a_scsiid a_status a_parent

	lspath -F "name parent path_id connection status" | sort -k 1 | while read a_dev a_parent a_pathid a_conn a_status; do
		# does not work for 6100-04
		# out1=$(lspath -l $a_dev -p $a_parent -i $a_pathid -E)
		out1=$(lspath -l $a_dev -p $a_parent -E -w $a_conn)

		a_pri=$(echo "$out1" | awk '/priority/ {print $2}') 
		a_nodename=$(echo "$out1" | awk '/node_name/ {print $2}') 
		a_scsiid=$(echo "$out1" | awk '/scsi_id/ {print $2}') 

		# existent attr = filler
		[ "x$a_pri" == "x" ] && a_pri=$filler
		[ "x$a_nodename" == "x" ] && a_nodename=$filler
		[ "x$a_scsiid" == "x" ] && a_scsiid=$filler
		
		printf "$f_header" $HOST $a_dev $a_status $a_parent $a_pathid $a_conn $a_pri $a_nodename $a_scsiid
	done

	return 0
}

function LPAR_tab5 {

	local f_header
	local a_vios a_disks a_vhosts name a_lun a_aixtdev a_vhost a_transfer a_queue a_status
	local a_hdisk a_pvid a_pathid a_parent a_conn res a_viosvhost out1 a_vtd

	# check weither running in vios or LPAR

	if [ -x /usr/ios/cli/ioscli ]; then
		# we're in vios

        f_header="%-20s\t%-33s\t%-10s\t%-50s\t%-16s\t%10s\t%10s\t%-10s\t%10s\n"
        [ $pheader -eq 1 ] && printf "$f_header" LPAR LUN VIOS Target_Device_Name VTD status vhost max_transfer qdepth

		# get vios name
		a_vios=$(prtconf -L | awk '{print $4}')

		# get all disks
		a_disks=$(lspv | cut -f1 -d' ')

		# get all vhostX and its backing device list
		a_vhosts=$(/usr/ios/cli/ioscli lsmap -all -field SVSA backing|paste -d"^" -s - | sed 's/SVSA/\!/g;s/Backing device//g' | tr '!' '\n' | tr -d '^' | sed 's/^-*//')

		# get backing device (aix_tdev) and LUN id
		/usr/ios/cli/ioscli lsmap -all -field vtd | awk '/VTD/ {print $2}' | while read a_vtd
		do 
			a_aixtdev=$(lsattr -El $a_vtd -a aix_tdev -F value)
			a_lun=$(lsattr -El $a_vtd -a LogicalUnitAddr -F value)
			# remove first 2 characters off LUN (0x)
			a_lun=$(echo $a_lun | sed 's/^0x//')
			a_status=$(lsdev -l $a_vtd -F status)
			a_vhost=$(lsdev -l $a_vtd -F parent)
			a_transfer=$filler
			a_queue=$filler
			if [ "x$a_aixtdev" != "x" ]; then 	# check for aixtdev is not empty
				echo "$a_disks" | grep -q "$a_aixtdev" 	# check if aixtdev matches any lspv disks
				if [ "$?" == "0" ]; then
					a_transfer=$(lsattr -El $a_aixtdev -a max_transfer -F value)
					# search for matching aix_tdev in vhost list (a_vhosts)
					#a_vhost=$(echo "$a_vhosts" | awk "/$a_aixtdev/ "'{print $1}')
					# get queue depth
					a_queue=$(lsattr -El $a_aixtdev -a queue_depth -F value)
					[ "x$a_queue" == "x" ] && a_queue=$filler
					[ "x$a_transfer" == "x" ] && a_transfer=$filler
				#else # all other VTD
					# a_aixtdev is XML-file with leading dot in basename or logical volume
					#local dir1 name1 name2
					#name1=$(basename $a_aixtdev)
					#dir1=$(dirname $a_aixtdev)
					#name2=$(echo $name1 | cut -c 2-)
					# for LV basename returns dot, so we don't change a_aixtdev
					# in case of XML-file, strip leading dot from file
					#[ "$dir1" != "." ] && a_aixtdev="${dir1}/${name2}"
					#a_vhost=$(echo "$a_vhosts" | awk "/$a_aixtdev/ "'{print $1}')
				fi				
			else
				a_aixtdev=$filler
				#a_vhost=$(lsdev -l $a_vtd -F "parent")
			fi
			printf "$f_header" $HOST $a_lun $a_vios $a_aixtdev $a_vtd $a_status $a_vhost $a_transfer $a_queue				
		done

	else
		# we're in LPAR

		f_header="%-20s\t%-10s\t%-10s\t%33s\t%20s\t%10s\t%10s\t%10s\t%10s\n"
		[ $pheader -eq 1 ] && printf "$f_header" LPAR VIOS HDISK_LPAR connection PVID vhost vscsi max_transfer qdepth

		# for each PV
		lspv | while read a_hdisk a_pvid a_trash; do

			# transfer size
			a_transfer=$(lsattr -El $a_hdisk -a max_transfer -F value)

			# for each path, we look for it's attributes
			lspath -l $a_hdisk -F "path_id parent connection" | while read a_pathid a_parent a_conn; do

				# we're looking for vscsi substring here
				# if not found, fill the blanks
				# if found, then we have vios and vhost parameters
				res=$(expr match $a_parent "vscsi")
				if [ $res -eq 0 ]; then
					a_vhost=$filler
					a_vios=$filler
				else
					a_viosvhost=$(echo "cvai" | kdb | awk '/'${a_parent}'/ {if ($1=="'${a_parent}'") { print $5 }}')
					a_vios=$(echo $a_viosvhost | awk -F"->" '{print $1}')
					a_vhost=$(echo $a_viosvhost | awk -F"->" '{print $2}')
				fi
				
				a_queue=$(lsattr -El $a_hdisk -a queue_depth -F value)
				[ "x$a_queue" == "x" ] && a_queue=$filler
				[ "x$a_vios" == "x" ] && a_vios=$filler
				[ "x$a_vhost" == "x" ] && a_vhost=$filler
				[ "x$a_transfer" == "x" ] && a_transfer=$filler

				printf "$f_header" $HOST $a_vios $a_hdisk $a_conn $a_pvid $a_vhost $a_parent $a_transfer $a_queue
			done
		done

	fi

	return 0
}

function LPAR_tab6 {

	local f_header="%-20s\t%-10s\t%10s\t%14s\t%14s\t%14s\t%10s\t%10s\t%10s\n"
	[ $pheader -eq 1 ] && printf "$f_header" LPAR SEA status real_adapter virt_adapters priority ctl_chan ha_mode pvid

	local a_ethlist
	local a_sealist a_sea a_seactrl a_seavirtlist a_seapvid a_seareal a_hamod a_seapriority out1

	# generating list of ethernet devices here
	a_ethlist=$(lsdev -Cc adapter -l ent\* -F "name,description,status")

	a_sealist=$(echo "$a_ethlist" | awk -F"," '/Shared Ethernet Adapter/ { print $1}')
	if [ "x$a_sealist" != "x" ] ; then
		for a_sea in $a_sealist; do
			a_status=$(echo "$a_ethlist" | awk -F"," '/'$a_sea',/ {print $3}')
			out1=$(lsattr -El $a_sea)
			a_seactrl=$(echo "$out1" | awk '{if ($1 == "ctl_chan") print $2}')
			a_seapvid=$(echo "$out1" | awk '{if ($1 == "pvid") print $2}')
			a_seareal=$(echo "$out1" | awk '{if ($1 == "real_adapter") print $2}')
			a_hamode=$(echo "$out1" | awk '{if ($1 == "ha_mode") print $2}')
			a_seavirtlist=$(echo "$out1" | awk '{ if ($1 == "virt_adapters") print $2}')
			a_seapriority=$(entstat -d $a_sea 2>/dev/null | awk '/Priority:/ {print $2; exit}')
			printf "$f_header" $HOST $a_sea $a_status $a_seareal $a_seavirtlist $a_seapriority $a_seactrl $a_hamode $a_seapvid
		done
	fi
	return 0
}

function f_check_ip {
#
# checks for IP on corresponding interface
# and returns "yes" or "no"
#
	local ent out1 out2
	ent=$1
	# check if empty
	if [ "x$ent" == "x" ]; then
		echo "no"
		return 1
	fi
	out1=$(echo $ent | tr -d 't')
	out2=$(ifconfig $out1 2>/dev/null | awk '/inet/ {print $2}')
	if [ "x$out2" == "x" ]; then
		out1="no"
	else
		out1="yes"
	fi
	echo $out1
	return 0
}

function f_ethernet_speed {
#
# returns link speed string
# for example: 1000 Mbps Full Duplex | Unknown
#
	local out1 out2
	local interfacelist interface
	interfacelist="$1"
	interface="$2"
	out1=$(echo "$interfacelist" | awk '$3 ~ /'$interface')/ {getline; if ($0 ~ /Media/) {FS=":"; print $2} else {print "'$filler'"}}')
	out2=$(echo $out1 | sed 's/[[:space:]]/\./g')
	echo $out2
	return 0
}

function f_ethernet_link {
#
# returns link status string
# for example: UNKNOWN | Up
#
	local out1 out2
	local interfacelist interface
	interfacelist="$1"
	interface=$2
	out1=$(echo "$interfacelist" | awk '$3 ~ /'$interface')/ {getline; if ($0 ~ /Link Stat/) {FS=":"; print $2} else {print "'$filler'"}}')
	echo $out1
	return 0
}

function f_check_tags {
#
# returns "yes" or "no" on interface, depending on VLAN Tags available
# 
	local out1 out2
    local interfacelist interface
	interfacelist="$1"
	interface=$2
	out1=$(echo "$interfacelist" | awk '$3 ~ /'$interface')/ {getline; if ($0 ~ /VLAN Tag IDs/) {FS=":"; print $2} else {print "'$filler'"}}' | tr -d ' ')
	case "$out1" in
		"")
			echo "no"
			;;
		$filler)
			echo "no"
			;;
		"None")
			echo "no"
			;;
		*)
			echo "yes"
			;;
	esac
	return
}

function f_vlans {
#
# run after f_check_tags only, so it always returns a string/list of vlan ids or N/A values
# but we leaving additional checks just in case
#
	local out1 out2
    local interfacelist interface
    interfacelist="$1"
    interface=$2
    out1=$(echo "$interfacelist" | awk '$3 ~ /'$interface'/ {getline; if ($0 ~ /VLAN Tag IDs/) {FS=":"; print $2}}')
	# out1 is now 3 values: empty; or a list of vlan ids; or string "  None"
	if [ "x$out1" == "x" ]; then
		# we have no vlans here, fill columns with $filler | N/A values
		return
	fi
	# strip leading blanks
	out2=$(echo $out1 | tr -d ' ')
	if [ "x$out2" == "None" ]; then
		return
	fi
	# last case of vlan ids in out2
	# first, sort it
	out2=$(for i in $out1; do echo $i; done | sort -n)
	# echoerr "$interface -" $out2
	local i v matched
	# compare defined vlans to the interface vlans
	# fill not found vlans with filler (N/A)
	for v in $VLANs; do
		matched=0
		# compare each one with VLANs
		for i in $out2; do
			if [ "$i" == "$v" ]; then
				echo -n " $i"
				matched=1
			fi
		done
		if [ "$matched" != "1" ]; then
			echo -n " $filler"
		fi
	done
	echo
	return
}

function LPAR_tab7 {

    local f_header="%-20s\t%-8s\t%10s\t%54s\t%14s\t%10s\t%-33s\t%8s\t%12s\t%-30s\t%6s\t%6s"
	local f_hdrstr="LPAR adapter Status Type MAC Link Port_Speed Base Backup_lnag location IP Tags"
	local i
	for i in $VLANs; do
		f_header="$f_header\t%6s" # each vlan get 6 blank characters for display
		f_hdrstr="$f_hdrstr $i"
	done
	f_header="$f_header\n" # add new-line character
	[ $pheader -eq 1 ] && printf "$f_header" $f_hdrstr

	local out1 out2 a_vlans a_status

    # listing of available/current ethernet devices
    local a_ethlist=$(lsdev -Cc adapter -l ent\* -F "name,description,physloc,status")

	# run netstat to gather interface status and other information, multiline string
	local s_netstat_out=$(netstat -v 2>/dev/null)

	# ethernet speed multiline
	local a_ethportspeed=$(echo "$s_netstat_out" |egrep -i "Media Speed Running|ETHERNET STATISTICS")
	# ethernet link multiline
	local a_ethportstatus=$(echo "$s_netstat_out" |egrep -i "Link Status|Physical Port Link State|ETHERNET STATISTICS")
	# ethernet tags
	local a_ethtags=$(echo "$s_netstat_out" |egrep -i "Tag|ETHERNET STATISTICS")

    # process virtual adapters
	local a_virtdesc=$(echo "Virtual I/O Ethernet Adapter (l-lan)" | tr ' ' '.')
	local a_virtlist=$(echo "$a_ethlist" | awk -F, '/Virtual I\/O Ethernet Adapter/ { print $1}')
	local a_virt a_virthw a_virtloc a_virttag 
	for a_virt in $a_virtlist; do
		a_status=$(echo "$a_ethlist" | grep "${a_virt}," | awk -F, '{print $4}')
		if [ "$a_status" == "Defined" ]; then
			a_virthw=$filler
		else
			a_virthw=$(lscfg -vpl $a_virt | grep "Network Address"  | tr '.' ' ' | awk '{print $3}')
		fi
		a_virtloc=$(echo "$a_ethlist" | grep "${a_virt}," | awk -F, '{print $3}')
		#a_virtspeed=$(echo "$a_ethportspeed" | awk '$3 ~ /'$a_virt'/ {getline; if ($0 ~ /Media/) {print} else {print "'$filler'"}}')
		a_virtspeed=$(f_ethernet_speed "$a_ethportspeed" $a_virt)
		a_virtip=$(f_check_ip $a_virt)
		a_virtlink="Up" # virtual is always UP
		a_virttag=$(f_check_tags "$a_ethtags" $a_virt)
		#process vlans
		if [ "$a_virttag" == "yes" ]; then
			a_vlans=$(f_vlans "$a_ethtags" $a_virt)
		else
			a_vlans=""
		fi
		[ "x$a_virtspeed" == "x" ] && a_virtspeed=$filler
		printf "$f_header" $HOST $a_virt $a_status $a_virtdesc $a_virthw "$a_virtlink" "$a_virtspeed" $filler $filler $a_virtloc $a_virtip $a_virttag $a_vlans
	done

	# process logical adapters
	local a_logidesc a_logilist a_logi a_logihw a_logiloc a_logitag
    a_logidesc=$(echo "Logical Host Ethernet Port (lp-hea)" | tr ' ' '.')
    a_logilist=$(echo "$a_ethlist" | awk -F, '/Logical Host Ethernet Port/ { print $1}')
    for a_logi in $a_logilist; do
		a_status=$(echo "$a_ethlist" | grep "${a_logi}," | awk -F, '{print $4}')
        a_logihw=$(lscfg -vpl $a_logi | grep "Network Address"  | tr '.' ' ' | awk '{print $3}')
        a_logiloc=$(echo "$a_ethlist" | grep "${a_logi}," | awk -F, '{print $3}')
		a_logispeed=$(f_ethernet_speed "$a_ethportspeed" $a_logi)
		a_logiip=$(f_check_ip $a_logi)
		a_logilink=$(f_ethernet_link "$a_ethportstatus" $a_logi)
		a_logitag=$(f_check_tags "$a_ethtags" $a_logi)
        #process vlans
        if [ "$a_logitag" == "yes" ]; then
            a_vlans=$(f_vlans "$a_ethtags" $a_logi)
        else
            a_vlans=""
        fi
		[ "x$a_logispeed" == "x" ] && a_logispeed=$filler
		printf "$f_header" $HOST $a_logi $a_status $a_logidesc $a_logihw "$a_logilink" "$a_logispeed" $filler $filler $a_logiloc $a_logiip $a_logitag $a_vlans
    done

    # process link aggregations
	local a_ladesc a_lalist a_la a_lahw a_laloc a_labase a_labackup a_laspeed a_latag
    a_ladesc=$(echo "EtherChannel / IEEE 802.3ad Link Aggregation" | tr ' ' '.')
    a_lalist=$(echo "$a_ethlist" | awk -F, '/EtherChannel/ {print $1}')
    for a_la in $a_lalist; do
		a_lahw=$filler
		a_laloc=$filler
		a_status=$(echo "$a_ethlist" | grep "${a_la}," | awk -F, '{print $4}')
		a_laspeed=$(f_ethernet_speed "$a_ethportspeed" $a_la)
		a_labase=$(lsattr -El $a_la -F "attribute value" | awk '/adapter_names/ {print $2}')
		a_labackup=$(lsattr -El $a_la -F "attribute value" | awk '/backup_adapter/ {print $2}')
		a_laip=$(f_check_ip $a_la)
		#a_lalink=$(f_ethernet_link "$a_ethportstatus" $a_la)
		a_lalink="Up" # always up
        a_latag=$(f_check_tags "$a_ethtags" $a_la)
        #process vlans
        if [ "$a_latag" == "yes" ]; then
            a_vlans=$(f_vlans "$a_ethtags" $a_la)
        else
            a_vlans=""
        fi
		[ "x$a_laspeed" == "x" ] && a_laspeed=$filler
		printf "$f_header" $HOST $a_la $a_status $a_ladesc $a_lahw "$a_lalink" "$a_laspeed" $a_labase $a_labackup $a_laloc $a_laip $a_latag $a_vlans
	done

    # process SEA interfaces
    local a_sealist a_seadesc a_sea a_seahw a_sealoc a_seatag
    a_seadesc=$(echo "Shared Ethernet Adapter" | tr ' ' '.')
    a_sealist=$(echo "$a_ethlist" | awk -F, '/Shared Ethernet Adapter/ { print $1}')
    for a_sea in $a_sealist; do
        a_seahw=$(entstat $a_sea 2>/dev/null| awk '/Hardware Address/ {print $3}' | tr -d ':' | tr '[:lower:]' '[:upper:]')
		a_sealoc=$filler
		a_status=$(echo "$a_ethlist" | grep "${a_sea}," | awk -F, '{print $4}')
		a_seaspeed=$(f_ethernet_speed "$a_ethportspeed" $a_sea)
		a_seaip=$(f_check_ip $a_sea)
		#a_sealink=$(f_ethernet_link "$a_ethportstatus" $a_sea)
		a_sealink="Up" # always up
        a_seatag=$(f_check_tags "$a_ethtags" $a_sea)
        #process vlans
        if [ "$a_seatag" == "yes" ]; then  
            a_vlans=$(f_vlans "$a_ethtags" $a_sea)
        else
            a_vlans=""
        fi
        # echo $a_sea $a_seahw $a_sealoc $a_seadesc
		[ "x$a_seaspeed" == "x" ] && a_seaspeed=$filler
		printf "$f_header" $HOST $a_sea $a_status $a_seadesc $a_seahw "$a_sealink" "$a_seaspeed" $filler $filler $a_sealoc $a_seaip $a_seatag $a_vlans
    done

    # process physical adapters
	local a_physlist a_physents a_phys a_physhw a_physloc a_physdesc a_phystag
	a_physlist=$(lsslot -c phb -F";" 2>/dev/null | grep " ent.")
	# if grep is not empty, i.e. we have something in output
	if [ "$?" == "0" ]; then
		a_physents=$(echo "$a_physlist" | awk -F";" '{print $3}')
		for a_phys in $a_physents; do
			out1=$(echo $a_phys | cut -c1-3)
			if [ $out1 == "ent" ]; then
				a_physhw=$(lscfg -vpl $a_phys | grep "Network Address"  | tr '.' ' ' | awk '{print $3}')
				a_status=$(echo "$a_ethlist" | grep "${a_phys}," | awk -F, '{print $4}')
				a_physloc=$(echo "$a_ethlist" | grep "${a_phys}," | awk -F, '{print $3}')
				a_physdesc=$(echo "$a_ethlist" | grep "${a_phys}," | awk -F, '{print $2}' | tr ' ' '.')
				a_physpeed=$(f_ethernet_speed "$a_ethportspeed" $a_phys)
				a_physip=$(f_check_ip $a_phys)
				a_physlink=$(f_ethernet_link "$a_ethportstatus" $a_phys)
				a_phystag=$(f_check_tags "$a_ethtags" $a_phys)
				#process vlans
				if [ "$a_phystag" == "yes" ]; then  
					a_vlans=$(f_vlans "$a_ethtags" $a_phys)
				else
					a_vlans=""
				fi
				[ "x$a_physpeed" == "x" ] && a_physpeed=$filler
				#echo $a_phys $a_physhw $a_physloc $a_physdesc
				printf "$f_header" $HOST $a_phys $a_status $a_physdesc $a_physhw "$a_physlink" "$a_physpeed" $filler $filler $a_physloc $a_physip $a_phystag $a_vlans
			fi
		done
	fi

    return 0
}


HOST=""

tmp=$(uname -L)
LPAR_ID=$(echo $tmp | cut -f1 -d' ')
if [ $LPAR_ID == "-1" ]; then
	HOST=`hostname`
else
	# get hostname/LPAR name, remove leading spaces and change spaces to underscores
	HOST=$(echo $tmp|awk '{ $1=""; print $0 }'| sed 's/^ *//;s/ /_/g')
fi


file="$HOST-tab1.txt"
echo -n "generating file $file ... "
LPAR_tab1 > "$file"
echo done

file="$HOST-tab2.txt"
echo -n "generating file $file ... "
LPAR_tab2 > "$file"
echo done

file=$HOST-tab3.txt
echo -n "generating file $file ... " 
LPAR_tab3 > "$file"
echo done 

file=$HOST-tab4.txt
echo -n "generating file $file ... "
LPAR_tab4 > "$file"
echo done

file=$HOST-tab5.txt
echo -n "generating file $file ... "
LPAR_tab5 > "$file"
echo done

file=$HOST-tab6.txt
echo -n "generating file $file ... "
LPAR_tab6 > "$file"
echo done

file=$HOST-tab7.txt
echo -n "generating file $file ... "
LPAR_tab7 > "$file"
echo done

exit 0

