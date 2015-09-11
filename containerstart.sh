#!/bin/bash
SCRIPT=`basename ${BASH_SOURCE[0]}`
function HELP {
    echo -e "$SCRIPT options: \n \
              -c/--container CONTAINERNAME \n \
              -m/--image IMAGENAME \n \
              -i/--ip IPADDRESS/MASK \n \
              -g/--gw GATEWAY \n \
              -d/--dns DNS \n \
              -s/--domain DOMAIN \n \
              -b/--bridge BRIDGE"
    exit 1
}

# set an initial value for the flag
ARG_B=0

# read the options
TEMP=`getopt -o c:m:i:g:d:s:b:h --long container:,image:,ip:,dns:,domain:,bridge:,help -n 'containerstart.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -c|--container)
            case "$2" in
                "") echo Container name missing; HELP; exit ; shift 2 ;;
                *) CONTAINERNAME=$2; echo -e "Container name:\t\t$CONTAINERNAME" ; shift 2 ;;
            esac ;;
        -m|--image)
            case "$2" in
                "") echo Image name missing; HELP; exit ; shift 2 ;;
                *) IMAGENAME=$2; echo -e "Image name:\t\t$IMAGENAME" ; shift 2 ;;
            esac ;;
        -i|--ip)
            case "$2" in
                "") echo IP address missing; HELP; exit ; shift 2 ;;
                *) IP=$2; echo -e "IP address:\t\t$IP" ; shift 2 ;;
            esac ;;
        -g|--gw)
            case "$2" in
                "") echo Gateway missing; HELP; exit ; shift 2 ;;
                *) GATEWAY=$2; echo -e "Gateway address:\t$GATEWAY" ; shift 2 ;;
            esac ;;
        -d|--dns)
            case "$2" in
                "") echo DNS server missing; HELP; exit ; shift 2 ;;
                *) DNS=$2; echo -e "DNS server:\t\t$DNS" ; shift 2 ;;
            esac ;;
        -s|--domain)
            case "$2" in
                "") echo Domain missing; HELP; exit ; shift 2 ;;
                *) DNSSEARCH=$2; echo -e "Domain:\t\t\t$DNSSEARCH" ; shift 2 ;;
            esac ;;
        -b|--bridge)
            case "$2" in
                "") echo Bridge missing; HELP; exit ; shift 2 ;;
                *) BRIDGE=$2; echo -e "Bridge:\t\t\t$BRIDGE" ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ -z $CONTAINERNAME ]; then
    echo provide container name
    HELP
    exit
fi
if [ -z $IMAGENAME ]; then
    echo provide image name
    HELP
    exit
fi
if [ -z $IP ]; then
    echo provide ip address
    HELP
    exit
fi
if [ -z $GATEWAY ]; then
    echo provide gateway
    HELP
    exit
fi
if [ -z $DNS ]; then
    echo provide dns server
    HELP
    exit
fi
if [ -z $DNSSEARCH ]; then
    echo provide domain
    HELP
    exit
fi
if [ -z $BRIDGE ]; then
    echo provide bridge port
    HELP
    exit
fi
echo Starting container $CONTAINERNAME with image $IMAGENAME, ip $IP, hostname $CONTAINERNAME, dns $DNS, domain $DNSSEARCH, bridge $BRIDGE

containerid=`docker run -d --net=none --name $CONTAINERNAME --hostname $CONTAINERNAME --dns $DNS --dns-search $DNSSEARCH $IMAGENAME`
ovs-docker add-port $BRIDGE eth0 $containerid --ipaddress=$IP --gateway=$GATEWAY
