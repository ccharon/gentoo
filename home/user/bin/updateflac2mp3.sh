#!/bin/bash

function addToPidQueue {
    pidQueue="${pidQueue} ${1}"
    numberOfProcesses=$((${numberOfProcesses}+1))
}

function refreshPidQueue {
    oldPidQueue=${pidQueue}
    pidQueue=""
    numberOfProcesses=0

    for pid in ${oldPidQueue} ; do
        if [ -d /proc/${pid}  ] ; then
            pidQueue="${pidQueue} $pid"
            numberOfProcesses=$((${numberOfProcesses}+1))
        fi
    done
}

function main {
    numberOfProcesses=0
    maxNumberOfProcesses=`grep -s -i "^processor\>" /proc/cpuinfo | wc -l`
    pidQueue=""

    [ ${maxNumberOfProcesses} -eq 0 ] && maxNumberOfProcesses=3

    while IFS= read -r -d '' item ; do
	oldpath="${path}"
        path=`dirname "${item}"`
        file=`basename "${item}"`

	#if [ "${oldpath}" != "${path}" ] ; then echo "Checking: ${path}" ; fi
	
	#unter der Annahme das hier nur Sammlung* Verzeichnisse vorbeikommen
	#den speziellen Namen dieser Sammlung rausfinden
	#sammlungName=`echo "${path}" | sed "s%.*Sammlung\(.*\)\/files.*%\Sammlung\1%"`
	
        flac2mp3Dir=`echo "${path}" | sed -e "s/\/files\/flac/\/files\/.cache/g" `
        
	if [ ! -d "${flac2mp3Dir}" ] ; then mkdir -p "${flac2mp3Dir}" ; fi

	if [ "${file##*.}" = "flac" ] ; then
            # Die Datei wird nur konvertiert, wenn die Zieldatei
            # noch nicht existiert.
    	    if [ ! -f "${flac2mp3Dir}/${file%.*}.mp3" ] ; then
    		echo "Creating mp3: ${file%.*}.mp3"
		flactomp3.sh -i "${item}" -o "${flac2mp3Dir}" &
    	        addToPidQueue ${!}
	    fi
	fi
	
	if [ "${file}" = "folder.jpg" ] ; then
            # Die Datei wird nur kopiert, wenn die Zieldatei
	    # noch nicht existiert.
    	    if [ ! -f "${flac2mp3Dir}/${file}" ] ; then
    		echo "Creating folder.jpg"
    		
		cp "${item}" "${flac2mp3Dir}" &
    	        addToPidQueue ${!}
	    fi
	fi
 
        while [ ${numberOfProcesses} -ge ${maxNumberOfProcesses} ] ; do
            refreshPidQueue
            sleep 1
        done

    done < <(find /data/archiv/Musik/files/flac -type f \( -name \*.flac -o -name folder.jpg \)  -print0)

    wait

    linkMusic.sh

    return 0
}

# executing the function main
main "${@}" || exit 1
exit 0
