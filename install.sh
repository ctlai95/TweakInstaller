#!/usr/bin/env bash

BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
COMMANDS_DIR="$BASE_DIR/commands"
DEB_FILE="$1"
TMP_DIR="tmp"
DYLIB_DIR="Library/MobileSubstrate/DynamicLibraries"
PREF_BUNDLES_DIR="Library/PreferenceBundles"
PREF_LOADER_DIR="Library/PreferenceLoader/Preferences"

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

source config

extract_data() {
    if [ -d "$TMP_DIR" ]; then
        panic "$TMP_DIR already exists. Aborting..."
    fi
    mkdir "$TMP_DIR"
    cd "$TMP_DIR"
    echo "Extracting $DEB_FILE..."
    ar -x "$DEB_FILE"
    DATA=`find ./data.* -type f`
    if [[ "$DATA" == *.gz ]]; then
        tar -xzf "$DATA"
    elif [[ "$DATA" == *.lzma ]]; then
        tar --lzma -xf "$DATA"
    else
        panic "$DATA type unrecognized. Aborting..."
    fi
}

respring() {
    ssh "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/respring.sh"
}

set_permissions() {
    ssh "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/set_perm.sh"
}

install_dylibs() {
    if [ -d "$DYLIB_DIR" ]; then
        cd "$DYLIB_DIR"
        scp * "root@$IP_ADDR:/bootstrap/Library/SBInject"
        cd "$BASE_DIR/$TMP_DIR"
    else
        warn "$DYLIB_DIR not found. Skipping..."
    fi
}

install_pref_bundles() {
    if [ -d "$PREF_BUNDLES_DIR" ]; then
        cd "$PREF_BUNDLES_DIR"
        scp -r * "root@$IP_ADDR:/bootstrap/Library/PreferenceBundles"
        cd "$BASE_DIR/$TMP_DIR"
    else
        warn "$PREF_BUNDLES_DIR not found. Skipping..."
    fi
}

install_pref_loaders() {
    if [ -d "$PREF_LOADER_DIR" ]; then
        cd "$PREF_LOADER_DIR"
        scp * "root@$IP_ADDR:/bootstrap/Library/PreferenceLoader/Preferences"
        set_permissions
        cd "$BASE_DIR/$TMP_DIR"
    else
        warn "$PREF_LOADER_DIR not found. Skipping..."
    fi
}

cleanup() {
    cd "$BASE_DIR"
    rm -rf "$TMP_DIR"
}

panic() {
    printf "${RED}$1${NC}\n"
    exit 1
}

warn() {
    printf "${YELLOW}$1${NC}\n"
}

print_usage() {
    echo "usage: $0 <path to .deb>"
}

if [ $# -eq 1 ]; then
    if [[ "$DEB_FILE" == *.deb ]]; then
        extract_data
        install_dylibs
        install_pref_bundles
        install_pref_loaders
        respring
        cleanup
    else
        panic "$DEB_FILE is not a .deb file!"
    fi
else
    print_usage
    exit 1
fi
