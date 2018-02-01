#!/usr/bin/env bash

if [ -f "$1" ]; then
    rm "$1"
elif [ -d "$1" ]; then
    rm -r "$1"
fi
