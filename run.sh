#!/usr/bin/env bash

readonly BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
readonly COMMANDS_DIR="$BASE_DIR/commands"
readonly TMP_DIR="tmp"
readonly LOCAL_DIR_LIST=(
    "Library/MobileSubstrate/DynamicLibraries"
    "Library/PreferenceBundles"
    "Library/PreferenceLoader/Preferences"
    "Library/Themes"
)
# The order of the paths must match the ones above
readonly MOBILE_DIR_LIST=(
    "/Library/TweakInject"
    "/Library/PreferenceBundles"
    "/Library/PreferenceLoader/Preferences"
    "/Library/Themes"
)
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

readonly ACTION="$1"
readonly DEB_FILE="$2"

respring_required=false
source config

copy_key() {
	ssh-copy-id -i "$ID_RSA_PATH" -p "$PORT" "root@$IP_ADDR" &> /dev/null
}

extract_data() {
    if [ -d "$TMP_DIR" ]; then
        panic "$TMP_DIR already exists."
    fi
    mkdir "$TMP_DIR"
    cd "$TMP_DIR"
    ar -x "$DEB_FILE"
    DATA=$(find data.* -type f)
    if [[ "$DATA" == *.gz ]]; then
        tar -xzf "$DATA"
    elif [[ "$DATA" == *.lzma ]]; then
        tar --lzma -xf "$DATA"
    else
        panic "$DATA type unrecognized"
    fi
}

perform_action() {
    action="$1"
    source_dir="${LOCAL_DIR_LIST[$2]}"
    target_dir="${MOBILE_DIR_LIST[$2]}"
    if [ -d "$source_dir" ]; then
        cd "$source_dir"
        for item in *; do
            exists=$(check_exists "$target_dir" "$item")
            if [[ "$ACTION" == "install" ]]; then
                if [ "$exists" == "true" ]; then
                    echo "$item already exists in $target_dir. Skipping..."
                    continue
                fi
                if [ -f "$item" ]; then
                    scp -P "$PORT" "$item" "root@$IP_ADDR:$target_dir"
                    respring_required=true
                elif [ -d "$item" ]; then
                    scp -P "$PORT" -r "$item" "root@$IP_ADDR:$target_dir"
                    respring_required=true
                fi
                if [ "$source_dir" == "Library/PreferenceLoader/Preferences" ]; then
                    set_permissions "$item"
                fi
            elif [[ "$ACTION" == "uninstall" ]]; then
                if [ "$exists" == "false" ]; then
                    echo "$item doesn't exist in $target_dir. Skipping..."
                    continue
                fi
                echo "Removing $item from $target_dir"
                remove "$target_dir/$item"
                respring_required=true
            fi
        done
        cd "$BASE_DIR/$TMP_DIR"
    fi
}

check_exists() {
    ssh -p "$PORT" "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/check_exists.sh" "$1" "$2"
}

set_permissions() {
    echo "Setting permissions for $1..."
    ssh -p "$PORT" "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/set_perm.sh" "$1"
}

remove() {
    ssh -p "$PORT" "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/remove.sh" "$1"
}

respring() {
    echo "Respringing device..."
    ssh -p "$PORT" "root@$IP_ADDR" "bash -s" < "$COMMANDS_DIR/respring.sh"
}

cleanup() {
    cd "$BASE_DIR"
    rm -rf "$TMP_DIR"
}

panic() {
    printf "${RED}$1${NC}\n"
    cleanup
    exit 1
}

print_usage() {
    echo "usage: $0 <install|uninstall> <path to .deb>"
}

if [ $# -eq 2 ]; then
	copy_key
    if [[ "$ACTION" == "install" || "$ACTION" == "uninstall" ]]; then
        if [[ "$DEB_FILE" == *.deb ]]; then
            extract_data
            for index in "${!LOCAL_DIR_LIST[@]}"; do
                perform_action "$ACTION" "$index"
            done
            cleanup
            if [ "$respring_required" = true ]; then
                respring
            fi
        else
            panic "$DEB_FILE is not a .deb file!"
        fi
    fi
else
    print_usage
    exit 1
fi
