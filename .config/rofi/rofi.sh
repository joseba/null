#!/usr/bin/env bash

declare -A DATA 

function readdata () {
    local LINES
    readarray -t LINES < "$1"
    for LINE in "${LINES[@]}";do
        KEY=${LINE%%=*}
        VALUE=${LINE#*=}
        DATA[$KEY]=$VALUE
    done
}

cd "$(dirname "$0")"
readdata "progs"
readdata "confs"
readdata "logs"

if [ -z "$1" ]; then
    for ID in "${!DATA[@]}"; do
        echo $ID
    done
else
    coproc ( ${DATA[$1]} > /dev/null 2>&1 )
fi 
