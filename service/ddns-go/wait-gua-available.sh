#!/bin/sh
# this file is meant to be used as the entrypoint of a ddns-go container
# refer to service/alist/docker-compose.yml for an example

# exec ddns-go only when global IPv6 is available
while true; do
    if ip -6 addr show scope global | grep 'inet6 [23]'; then
        sleep 3
        if ping -c1 -W5 $(ip -6 route | awk '/^[23]/{sub(/\/.*/, "", $1); print $1 "1"; exit}'); then
            exec /app/ddns-go -f 600
        fi
    fi
done
