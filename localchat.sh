#!/bin/bash

port=
mode=  
interface=
host_ip=
error_code_fail=2
min_port=1024
max_port=65535
declare -a output_text

function determine_ip {
    host_ip=$(ip -o -4 addr show ${1} | awk '{ split($4, ip_addr, "/"); print ip_addr[1] }')
    if [[ $host_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        output_text+=("Host Private Address: ${host_ip}.")
        return 0
    else
        output_text+=("Error! Failed to obtain private ip for interface: ${1}")
        return $error_code_fail
    fi
}

function can_bind_port() {
    # status code of this command indicates whether
    # there was output (bad, means port is in use)
    # or not (good, no processes using the port)
    ! lsof -i udp:"$1" > /dev/null;
}

function find_available_port {
    echo "Checking for an available port..."
    
    open_port_net_yet_found=true
    while [ open_port_net_yet_found ]; do
        temp_port=$(shuf -i${min_port}-${max_port} -n1) # generate random port number in range
        echo "...Trying port ${temp_port}"
        can_bind_port $temp_port
        port_status=$? # get return status of previous command
        if [ "$port_status" -eq "0" ]; then # 0 means port is safe to use
            port=$temp_port
            open_port_net_yet_found=false
            break
        fi
    done
    echo "Port ${port} Available! Binding..."
    return 0
}

function start_server {
    echo "+-----------------------------------+"
    echo " Starting Local Chat in SERVER mode"
    echo "+-----------------------------------+"
    echo
    while IFS= read -p "Me: " -r input;
    do
        send_message $input;
        # -l: listen mode -u use UDP protocol
    done | nc $host_ip -p $port -l -u
}

function start_client {
    echo "+-----------------------------------+"
    echo " Starting Local Chat in CLIENT mode"
    echo "+-----------------------------------+"
    echo
    while IFS= read -p "Me: " -r input;
    do
        send_message $input;
        # connect to listening server using UDP protocol
    done | nc $host_ip $port -u
}

function send_message {
    payload="$*"
    # Transmit message ONLY if input is not empty
    if [ $1 ]; then
        if [ "$mode" = "SERVER" ]; then
            printf "\nServer: %s \nMe: " "${payload}";
        else # client mode
            printf "\nClient: %s \nMe: " "${payload}";
        fi
        return 0 # payload transmitted
    else
        return $error_code_fail # blank input
    fi
}

function init {
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
    key="$1"

    case $key in
        -c|--client-mode)
        mode="CLIENT"
        shift # past argument
        ;;
        -a|--server-address)
        host_ip="$2"
        shift # past argument
        shift # past value
        ;;
        -p|--server-port)
        port="$2"
        shift # past argument
        shift # past value
        ;;
        -i|--interface)
        interface="$2"
        shift # past argument
        shift # past value
        ;;
        -s|--server-mode)
        mode="SERVER"
        shift # past argument
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
    done
    # set -- "${POSITIONAL[@]}" # restore positional parameters
    
    if [ "$mode" = "SERVER" ]; then
        determine_ip $interface
        find_available_port
        for i in "${output_text[@]}"; do echo "$i"; done
        start_server
    else
        for i in "${output_text[@]}"; do echo "$i"; done
        start_client
    fi
    
}

init "$@"


# meat without all the extra fat
# while IFS= read -p "Me: " -r input; do printf "\nServer: %s \nMe: " "$input"; done | nc localhost 55555 -l
# while IFS= read -p "Me: " -r input; do printf "\nClient: %s \nMe: " "$input"; done | nc localhost 55555

