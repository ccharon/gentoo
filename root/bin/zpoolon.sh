#!/bin/sh
##
# this script is intended to be run as root to import a zpool located on an external enclosure
# poolname - the pool that should be imported
# deviceList - list of devices that need to be available
#
# before removing the external enclosure use the command "zpool export <poolname>" 
##

poolname=zpool

declare -a deviceList=(
"/dev/disk/by-id/ata-WDC_1"
"/dev/disk/by-id/ata-WDC_2"
"/dev/disk/by-id/ata-WDC_3"
"/dev/disk/by-id/ata-WDC_4"
"/dev/disk/by-id/ata-WDC_5"
)

####
# Check if all drives are available, only then the zpool should be imported 
####
echo "Checking drive availability"
fail=0
for device in "${deviceList[@]}" ; do
    if ! [ -b "${device}" ] ; then 
	echo -e "\e[91m[FAILED] \e[39m${device}"
	fail=1
    else
	echo -e "\e[32m[OK] \e[39m${device}"
    fi
done

if [ ${fail} -ne 0 ] ; then echo "Device(s) not available" ; exit 1 ; fi

echo

####
# Set timeout in case of read errors. these drives support the feature but "forget" about TLER after power down
####
echo "Activating TLER"
fail=0
for device in "${deviceList[@]}" ; do
    state=$(smartctl -l scterc ${device})
    if [[ "${state}" != *"70 (7.0 seconds)"*  ]] ; then
        smartctl -q silent -d sat -l scterc,70,70 "${device}"

        if [ ${?} -ne 0 ] ; then
	    echo -e "\e[91m[FAILED] \e[39mTLER could not be activated for ${device}"
	    fail=1
        else
	    echo -e "\e[32m[OK] \e[39mTLER activated for ${device}"
        fi
    else
	echo -e "\e[32m[OK] \e[39mTLER already active for ${device}"
    fi
done

if [ ${fail} -ne 0 ] ; then echo "TLER Step failed" ; exit 1 ; fi

echo

####
# import zpool if possible / necessary
####
echo "Importing zfs pool"
zpools=$(zpool list -Ho name)
if [[ "${zpools}" != *"${poolname}"*  ]] ; then

    imports=$(zpool import)
    if [[ "${imports}" != *"${poolname}"*  ]] ; then
	echo -e "\e[91m[FAILED] \e[39m${poolname} not found"
    else
	$(zpool import ${poolname})
	echo -e "\e[32m[OK] \e[39m${poolname} imported"
    fi
else
    echo -e "\e[32m[OK] \e[39m${poolname} already imported"
fi
