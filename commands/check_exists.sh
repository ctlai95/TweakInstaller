#!/usr/bin/env bash

if [ -f "$1/$2" ]; then
    echo true
elif [ -d "$1/$2" ]; then
    echo true
else
    echo false
fi
