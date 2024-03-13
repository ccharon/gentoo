#!/usr/bin/env bash

usage() {
  command=${0##*/}
  echo "Usage: ${command} -d imgdir [-D] [-l disklabel] [-o imgdir.img]";
  echo " -d, --directory   directory to convert to floppy image"
  echo " -l  --label       label of floppy, defaults to imgdir if omitted"
  echo " -o  --output      target image, defaults to imagedir.img in current directory"
  echo " -D  --dmf         create a 1.68MB DMF Image"
  echo " -h  --help        shows this help"
  echo
  echo "Examples:"
  echo "${command} --directory /tmp/floppy --label stuff --output /tmp/floppy.img"
  echo "${command} --directory /tmp/floppy --label stuff --dmf --output /tmp/floppy.img"
  echo "${command} --directory /tmp/floppy"
  echo "${command} without parameters displays this help"
  echo
}

# No parameters, just show usage
if [ ${#} -lt 1 ]; then usage ; exit 0; fi

opts=$(getopt --options d:l:o:Dh --long directory:,label:,output:,dmf,help  --name "$0" -- "$@")
if [ ${?} -ne 0 ] ; then usage ; exit 1 ; fi

eval set -- "${opts}"

directory=""
label=""
output=""
format="144M"

while true ; do
  case "${1}" in
    -d | --directory ) directory="${2}"; shift 2;;
    -l | --label ) label="${2}"; shift 2;;
    -o | --output ) output="${2}"; shift 2;;
    -D | --dmf ) format="168M" ; shift;;
    -h | --help ) usage ; exit 0 ;;
    -- ) shift ; break;;
    *) usage ; exit 1;;
  esac
done

# sanity checks

which mcopy 2>/dev/null 1>&2
if [ ${?} -ne 0 ] ; then echo "mcopy not found, please install mtools" ; exit 1 ; fi

which mformat 2>/dev/null 1>&2
if [ ${?} -ne 0 ] ; then echo "mformat not found, please install mtools" ; exit 1 ; fi

# image directory
directory="$(realpath -s "${directory}")"
if [ ${?} -ne 0 ] ; then echo "can not resolve path to directory ${directory}" ; exit 1 ; fi
if ! [ -d "${directory}" ] ; then echo "directory ${directory} is not a directory" ; exit 1 ; fi

dirname="$(basename "${directory}")"
if [[ ${#label} -eq 0 && ${#dirname} -gt 11 ]] ; then
    echo "directory ${dirname} has to be 11 characters or less,"
    echo "shorten dirname or provide a custom label ( see --label)"
    exit 1
fi

# label
if [ ${#label} -gt 11 ] ; then
    echo "label ${label} has to be 11 characters or less,"
    echo "shorten label or omit parameter"
    exit 1
fi

if [ ${#label} -eq 0 ] ; then label="${dirname}" ; fi

# output file
if [ ${#output} -eq 0 ] ; then output="${PWD}/${label,,}.img" ; fi
if [ -f "${output}" ] ; then echo "output ${output} already exists. please choose a different file" ; exit 1 ; fi

# output file should not be in image dir
outputdir="$(dirname ${output})"
if [ "${outputdir}" == "${directory}" ] ; then echo "${output} can not be created in imagedir" ; exit 1 ; fi

echo
echo "Image directory: ${directory}"
echo "Output file    : ${output}"
echo "Disk label     : ${label^^}"
echo

if [ "${format}" == "144M" ] ; then
    echo "creating 1.44MB image (mformat -t 80 -h 2 -s 18 -v ${label^^} -C -i ${output} ::) ..."
    mformat -t 80 -h 2 -s 18 -v "${label^^}" -C -i "${output}" ::
    if [ ${?} -ne 0 ] ; then echo "failed to create image ${output}" ; exit 1 ; fi
else
    echo "creating 1.68MB 2048 byte cluster dmf image (mformat -t 80 -h 2 -s 21 -r 1 -c 4 -v ${label^^} -C -i ${output} ::) ..."
    mformat -t 80 -h 2 -s 21 -r 1 -c 4 -v "${label^^}" -C -i "${output}" ::
    if [ ${?} -ne 0 ] ; then echo "failed to create image ${output}" ; exit 1 ; fi
fi    

echo
echo "transfer files (mcopy -v -i ${output} ${directory}/* ::/) ..."
result=$(mcopy -v -i "${output}" "${directory}"/* ::/)
if [ ${?} -ne 0 ] ; then echo "failed to transfer files" ; exit 1 ; fi
