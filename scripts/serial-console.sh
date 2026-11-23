#!/bin/sh

while true; do
    if [ -e /dev/ttyUSB0 ]; then
        picocom -b 115200 /dev/ttyUSB0
    fi
    sleep 0.5
done
