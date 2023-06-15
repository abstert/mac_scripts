#!/bin/bash
#   Update Chrome
#   This script should be used to install the latest
#   version of Google Chrome.app for macOS.
#
#   This was designed to be deployed via JSS.  
#
#set -x
#######################################################################
# Variables
#######################################################################
appDir="/Applications"
appName="Google Chrome.app"
app="$appDir/$appName"
currentUser=$(stat -f%Su /dev/console)
chromePkg="/tmp/Google Chrome.pkg"
#chromeUrl="${4}"
#newVersion="${5}"
chromeUrl="https://dl.google.com/chrome/mac/universal/stable/gcem/GoogleChrome.pkg"
#newVersion_int=$(echo "$newVersion" | tr -d '.')
######################################################################
# Functions
######################################################################
CheckVersion() {
    local ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$1"/Contents/Info.plist)
    echo "$ver"
}

GetWebVersion() {
    local file="$1"
    rm -rf /tmp/chrome
    pkgutil --expand "$file" /tmp/chrome
    webVer=$(xmllint --xpath '/installer-gui-script/pkg-ref/bundle-version/bundle' /tmp/chrome/Distribution | cut -d" " -f2 | cut -d"=" -f2 | xargs)
    if [ -z "$webVer" ]; then
        ExitScript "ERROR: error reading version from $1" "1"
    fi
    echo "$webVer"
}

CompareVersions() {
    # Convert version string to integar
    local current="$1"
    local latest="$2"
    v1=$(echo "$current" | tr -d '.')
    v2=$(echo "$latest" | tr -d '.')
    if [ $v1 -ge $v2 ]; then
    # The current version is newer then the web version
        return 0
    else
    # The current version is old and needs an upgrade
        return 1
    fi
}

DownloadChrome() {
    local url="$1"
    local file="$2"
    curl -so "$file" "$url" 
    if [ ! -e "$file" ]; then
        return 1
    else
        return 0
    fi
}

InstallApp() {
    # Install the pkg
    if [ -e "$1" ]; then
        echo "Installing $1..."
        installer -pkg "$1" -target /
    else
        ExitScript "Installer could not find the installer at: $1" 1
    fi
}

CleanUp() {
    if [ -e "$chromePkg" ]; then
        rm -rf "$chromePkg"
    fi
    if [ -e "/tmp/chrome" ]; then
        rm -rf /tmp/chrome
    fi
}

ExitScript() {
    # $1 is the string to echo
    # $2 is the exit code
    CleanUp
    echo "$1"
    exit "$2"
}

######################################################################
# Running Logic
######################################################################
# Check if Google Chrome.app is installed in the Applications Directory
if [ -e "$app" ]; then
    echo "Google Chrome is installed."
    # Check the version of the installed app
    localVersion=$(CheckVersion "$app")
    echo "Currently installed version is: $localVersion"
else
    echo "Google Chrome Not installed."
    localVersion="0"
fi
echo "Checking latest version of Google Chrome..."
DownloadChrome "$chromeUrl" "$chromePkg"
if [ "$?" = 1 ]; then
    ExitScript "Downloading Chrome: Failed to download the file" "1"
fi

webVersion=$(GetWebVersion "$chromePkg")
echo "Latest version of Chrome is: $webVersion"
#CompareVersions "$localVersion" "$webVersion"
/bin/zsh -c "autoload is-at-least;is-at-least $webVersion $localVersion"
if [ $? = 0 ]; then
    ExitScript "Current version installed is the latest version." "0"
fi

echo "The currently installed version is old and needs to be upgraded."

InstallApp "$chromePkg"
newLocal=$(CheckVersion "$app")
CompareVersions "$newLocal" "$webVersion"
if [ $? != 1 ]; then
    ExitScript "Current version installed is the latest version." "0"
else
    ExitScript "Failed to install the latest version of chrome." "1"
fi
