#!/bin/bash
#set -x
# Find if Firefox.app is installed in the /Applications folder
# If so, get the currently installed version number.
# Get the latest version from the Mozilla website.
# If the installed is less then the current, check if app is running.
# If not running, install, exit otherwise.

app_path="/Applications/Firefox.app"
app_name=$(basename "$app_path")
url="https://download.mozilla.org/?product=firefox-pkg-latest-ssl&os=osx&lang=en-US"
download_path="/tmp/Firefox_XXX.pkg"

function Download_App() {
    local download_path="$1"
    if [[ -e "$download_path" ]]; then
        # File already exists
        return
    fi
    curl -Ls -o "$download_path" "$url"
}

function Running_State() {
    local running
    if [[ $(ps aux | grep -v grep | grep -c "$app_name") != 0 ]]; then
        # app is running, exit
        return 1
    fi
    return 0
}

function Get_Local_Version() {
    local app_ver
    app_ver=$(defaults read "$app_path"/Contents/Info.plist CFBundleShortVersionString)
    echo "$app_ver"
}

function Get_Latest_Version() {
    local latest_ver
    download_url=$(curl -Ls -o /dev/null -w %{url_effective} "$url")
    download_file=$(basename "$download_url")
    latest_ver=$(printf '%b' "${download_file//%/\\x}" | awk '{print $2}' | sed 's/.pkg//g')
    echo "$latest_ver"
}

function Check_Exist() {
    local path="$1"
    if [[ -d "$path" ]]; then
        return 0 
        # exists
    else
        return 1
        # does not exist
    fi
}

function Install_App() {
    local installer_path="$1"
    /usr/sbin/installer -pkg "$installer_path" -target /
    if [[ $? != 0 ]]; then
        echo "[ERROR] Installation of $app_name failed"
        exit 1
    fi
    echo "$app_name installed, removing file $installer_path"
    rm -f "$installer_path"
}
###########################################################################
# Main
###########################################################################
echo "Checking if $app_path exists..."
Check_Exist "$app_path"
if [[ $? != 0 ]]; then
    # Firefox not found, exit
    echo "$app_name not installed at $(dirname $app_path)"
    Download_App "$download_path"
    Install_App "$download_path"
    exit 0
fi
echo "$app_path exists, checking local version against latest..."
# app exists, continue
local_version=$(Get_Local_Version)
latest_version=$(Get_Latest_Version)

/bin/zsh -c "autoload is-at-least;is-at-least ${latest_version} ${local_version}"
if [[ $? = 0 ]]; then
    echo "Current Version installed is the latest or greater, no need to upgrade."
    exit 0
fi
echo "Upgrade required..."
# app exists and is not the latest
# download file
download_path=$(echo "$download_path" | sed "s/XXX/$latest_version/g")
Download_App "$download_path"
# Check if Firefox is running before installing
echo "Checking if $app_name is running..."
Running_State
if [[ $? != 0 ]]; then
    echo "$app_name is running, can not continue install"
    exit 1
fi
echo "$app_name is not running, installing now...."
rm -rf "$app_path"
Install_App "$download_path"

