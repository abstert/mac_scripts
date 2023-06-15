#!/bin/bash
#
#set -x
#   Microsoft Teams Updater
#####################################
#   Variables
#####################################
teamsPath="/Applications/Microsoft Teams.app"
teamsUrl="https://go.microsoft.com/fwlink/?linkid=869428"


#####################################
#   Functions
#####################################
CheckExistence() {
    local appPath="$1"
	if [ -e "$appPath" ]; then
		return 0
	else
		return 1
	fi
}

DownloadApp() {
    # First parameter is the Teams download url
    CheckExistence "$pkgPath"
    if [ $? = 0 ]; then
        # Remove old or failed downloads
        rm "$pkgPath"
    fi
    curl --retry 1 --retry-max-time 30 -s -L -C - "$1" -o "$pkgPath"
    if [ $? != 0 ]; then
        ExitScript "Teams - Failed download: $pkgPath" "1"
    fi
}

ExitScript() {
    local output="$1"
    local exitCode="$2"
    echo "$output"
    exit "$exitCode"
}

GetDownloadUrl() {
	local url="$1"
	local downloadUrl=$(curl -sIL "$url" | grep location | awk '{print $2}' | tr -d '\r')
    echo "$downloadUrl"
}

GetLocalVersion() {
    local path="$1"
    local plistNode="$2"
    local version=0
    CheckExistence "$path"
    if [ $? != 0 ]; then
        echo "$version"
        return
    fi
    version=$(/usr/libexec/PlistBuddy -c "print :$plistNode" "$path" | sed 's/\.//g')
    echo "$version"
}

GetPackagePath() {
    local pkgName=$(printf "%s" "$teamsDownloadUrl" | sed 's@.*/@@' | tr -d '\r')
    local pkgPath="/tmp/$pkgName"
    echo "$pkgPath"
}

GetWebVersion() {
    local url="$1"
    local version=$(curl -sIL "$url" | grep location | awk '{print $2}' | awk -F'/' '{print $5}' | sed 's/\.//g')
    echo "$version"
}

InstallApplication() {
    #local pkgPath="$1"
    printf "Teams - Installing %s\n" "$(basename "$pkgPath")"
    if ! /usr/sbin/installer -verbose -pkg "$pkgPath" -target / > /dev/null 2>&1; then
        ExitScript "Teams - Failed to install: $pkgPath" "2"
    else
        printf "Teams - Installed successfully: %s\n" "$pkgPath" 
    fi
}
#####################################
#   Main Logic
#####################################
printf "Checking Teams is installed...\n"
CheckExistence "$teamsPath"
if [ $? = 0 ]; then
    # Teams is installed, need to check version info
    localVersion=$(GetLocalVersion "$teamsPath/Contents/Info.plist" "CFBundleGetInfoString")
    printf "Local Teams version is: %s\n" "$localVersion"
    webVersion=$(GetWebVersion "$teamsUrl")
    printf "Latest Teams version is: %s\n" "$webVersion"
    if [ $localVersion -ge $webVersion ]; then
        ExitScript "Teams application is running the latest version, exiting." 0
    fi
fi
printf "Teams must be upgraded/installed...\n"
teamsDownloadUrl=$(GetDownloadUrl "$teamsUrl")
pkgPath=$(GetPackagePath "$teamsDownloadUrl")
printf "Getting Teams installer from: %s\n" "$teamsDownloadUrl"
printf "Downloading to %s\n" "$pkgPath"
DownloadApp "$teamsDownloadUrl" "$pkgPath"
#ps ax | grep "MacOS/Teams" | grep -v grep > /dev/null
#if [ $? = 0 ]; then
if ps ax | grep "MacOS/Teams" | grep -v grep > /dev/null; then
    killall Teams
    # App is running, skip installing
    #ExitScript "Teams is currently running, skipping install" "1"
fi
InstallApplication "$pkgPath"
rm "$pkgPath"


