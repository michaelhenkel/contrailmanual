#!/bin/bash

# set an initial value for the flag
ARG_B=0

# read the options
TEMP=`getopt -o a:b:c: --long arga::,argb,argc: -n 'a.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -a|--arga)
            case "$2" in
                "") ARG_A='some default value' ; shift 2 ;;
                *) ARG_A=$2 ; shift 2 ;;
            esac ;;
        -b|--argb) 
            case "$2" in
                "") ARG_B='some default value' ; shift 2 ;;
                *) ARG_B=$2 ; shift 2 ;;
            esac ;;
        -c|--argc)
            case "$2" in
                "") shift 2 ;;
                *) ARG_C=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

# do something with the variables -- in this case the lamest possible one :-)
echo "ARG_A = $ARG_A"
echo "ARG_B = $ARG_B"
echo "ARG_C = $ARG_C"
