#!/usr/bin/env bash

readonly BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
readonly COMMANDS_DIR="$BASE_DIR/commands"
readonly DEB_FILE="$1"
readonly TMP_DIR="tmp"

readonly LOCAL_DIR_LIST=(
    "Library/MobileSubstrate/DynamicLibraries"
    "Library/PreferenceBundles"
    "Library/PreferenceLoader/Preferences"
    "Library/Themes"
)
# The order of the paths must match the ones above
readonly MOBILE_DIR_LIST=(
    "/bootstrap/Library/SBInject"
    "/bootstrap/Library/PreferenceBundles"
    "/bootstrap/Library/PreferenceLoader/Preferences"
    "/bootstrap/Library/Themes"
)

readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

source config

extract_data() {
    if [ -d "$TMP_DIR" ]; then
        panic "$TMP_DIR already exists."
    fi
    mkdir "$TMP_DIR"
    cd "$TMP_DIR"
    ar -x "$DEB_FILE"
    DATA=`find data.* -type f`
    if [[ "$DATA" == *.gz ]]; then
        tar -xzf "$DATA"
    elif [[ "$DATA" == *.lzma ]]; then
        tar --lzma -xf "$DATA"
    else
        panic "$DATA type unrecognized"
    fi
}

install_item() {
    source_dir="${LOCAL_DIR_LIST[$1]}"
    target_dir="${MOBILE_DIR_LIST[$1]}"
    if [ -d "$source_dir" ]; then
        cd "$source_dir"
        for item in *; do
            if [ -f $item ]; then
                scp "$item" "root@$IP_ADDR:$target_dir"
            elif [ -d $item ]; then
                scp -r "$item" "root@$IP_ADDR:$target_dir"
            fi
            if [ "$source_dir" == "Library/PreferenceLoader/Preferences" ]; then
                set_permissions "$item"
            fi
        done
        cd "$BASE_DIR/$TMP_DIR"
    fi
}

set_permissions() {
    echo "Setting permissions for $1..."
    ssh "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/set_perm.sh" "$1"
}

respring() {
    echo "Respringing device..."
    ssh "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/respring.sh"
}

cleanup() {
    cd "$BASE_DIR"
    rm -rf "$TMP_DIR"
}

panic() {
    printf "${RED}$1${NC}\n"
    exit 1
}

print_usage() {
    echo "usage: $0 <path to .deb>"
}

if [ $# -eq 1 ]; then
    if [[ "$DEB_FILE" == *.deb ]]; then
        extract_data
        for index in "${!LOCAL_DIR_LIST[@]}"; do
            install_item "$index"
        done
        cleanup
        respring
    else
        panic "$DEB_FILE is not a .deb file!"
    fi
else
    print_usage
    exit 1
fi
