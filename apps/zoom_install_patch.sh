#!/bin/bash
#####################################################################################################
#
# NAME
#       ZoomInstall.sh -- Installs or updates Zoom
####################################################################################################
#
# Set preferences - set to anything besides "true" to disable
ssohost="ENTER_SSO_NAME_HERE"
pkgfile="ZoomInstallerIT.pkg"
plistfile="us.zoom.config.plist"
url="https://zoom.us/client/latest/ZoomInstallerIT.pkg"
##########################################################################
#   Functions
##########################################################################
CleanUp() {
	if [ -e /tmp/"$plistfile" ]; then
		rm -rf /tmp/"$plistfile"
	fi

	if [ -e /tmp/"$pkgfile" ]; then
		rm -rf /tmp/"$pkgfile"
	fi
}

CreatePlist() {
	# Construct the plist file for preferences
	touch "$1"
	/usr/libexec/PlistBuddy -c "ADD :nogoogle string 1" "$1"
	/usr/libexec/PlistBuddy -c "ADD :nofacebook string 1" "$1"
	/usr/libexec/PlistBuddy -c "ADD :ZAutoSSOLogin bool true" "$1"
	/usr/libexec/PlistBuddy -c "ADD :ZSSOHost string $sshhost" "$1"
	/usr/libexec/PlistBuddy -c "ADD :ZRemoteControllAllApp bool true" "$1"
	/usr/libexec/PlistBuddy -c "ADD :ZAutoUpdate bool true" "$1"
	/usr/libexec/PlistBuddy -c "ADD :ZDisableVideo bool true" "$1"
	/usr/libexec/PlistBuddy -c "ADD :MuteVoipWhenJoin bool true" "$1"
	/usr/libexec/PlistBuddy -c "ADD :ZRemoteControlAllApp bool true" "$1"
}

CheckZoomProcess () {
	zoomRunning=$(ps -ef | grep zoom | grep CptHost | grep -v grep)
	if [ -z "$zoomRunning" ]; then
	# Zoom may be running, but it is not in an active meeting.
		return 0
	else
	# Zoom is running and in an active meeting.
		return 1
	fi
}

DoesZoomExist() {
	if [ ! -e "/Applications/zoom.us.app" ]; then
		currentinstalledver="0"
		/bin/echo "Zoom is not installed"
		return 0
	fi
	currentinstalledver=$(/usr/bin/defaults read /Applications/zoom.us.app/Contents/Info CFBundleVersion)
	/bin/echo "Current installed version is: $currentinstalledver"
	return 1
}

DownloadZoom() {
	# Download and install new version
	/bin/echo "Downloading Zoom to /tmp/$pkgfile ..."
	/usr/bin/curl -sL -o /tmp/"$pkgfile" "$url"
}

ExitScript() {
	local mesg="$1"
	local exitCode="$2"
	/bin/echo "$mesg"
	exit "$exitCode"
}

# Get the latest version of Reader available from Zoom page.
GetLatestVersion() {
	local latestLink="https://zoom.us/client/latest/ZoomInstallerIT.pkg"
	#local OSvers_URL=$(sw_vers -productVersion | sed 's/[.]/_/g' )
	#local userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"
	local response=$(curl -sIL "$latestLink" --write-out '%{http_code} %{size_header} %{redirect_url}')
	local location=$(grep "location: " <<<"$response" | awk '{print $2}')
	latestver=$(awk -F '/' '{print $4}' <<<"${location#*/}")
	#latestver=$(/usr/bin/curl -s -A "$userAgent" https://zoom.us/download | grep "$pkgfile" | awk -F'/' '{print $3}')
	/bin/echo "$latestver"
}

InstallZoom() {
	bin/echo "Installing Zoom from $pkgfile ..."
	/usr/sbin/installer -allowUntrusted -pkg /tmp/"$pkgfile" -target /
	if [ "$?" != 0 ]; then
		ExitScript "Installer command failed" 1
	fi
	/bin/echo "Deleting downloaded PKG at /tmp/$pkgfile"
	/bin/rm /tmp/"$pkgfile"
}

KillZoom () {
	killall zoom
	zoomPid=$(ps ax | grep -v grep | grep "/Applications/zoom.us.app/Contents/MacOS/zoom" | awk '{print $1}')
	if [ ! -z "$zoomPid" ]; then
		kill $zoomPid
	fi
}

###########################################################
#   Main Logic
##########################################################
# Get the version number of the currently-installed Zoom, if any.
latestVersion=$(GetLatestVersion)
/bin/echo "Latest Version is: $latestVersion"
#url="https://zoom.us/client/$latestVersion/ZoomInstallerIT.pkg"
#/bin/echo "Download URL: $url"

# Check if Zoom Exists and compare versions
DoesZoomExist
if [ $? != 0 ]; then
	if [ "${currentinstalledver}" = "${latestVersion}" ]; then
	# Zoom is already current, so no need to do anything.
		ExitScript "Zoom is already up to date, running $currentinstalledver" 0
	fi
fi

#Checking if Zoom is currently Running
CheckZoomProcess
if [ $? != 0 ]; then
	ExitScript "Zoom is running and in a meeting, exiting..." 1
fi

DownloadZoom
CheckZoomProcess
if [ $? != 0 ]; then
	ExitScript "Zoom is running and in a meeting, exiting..." 1
fi
/bin/echo "Zoom is not currently in a meeting, upgrading..."
KillZoom
if [ -f /Library/Preferences/"$plistfile" ]; then
	/bin/mv /Library/Preferences/"$plistfile" /Library/Preferences/"$plistfile".plistold
	/bin/echo "Renaming Zoom Plist to plistold..."
else
	/bin/echo "Zoom plist does not exist.  Creating new plist..."
fi
InstallZoom
/bin/mv /Library/Preferences/"$plistfile".plistold /Library/Preferences/"$plistfile"
# Create the preference file
#tempPlist="/tmp/${plistfile}"
#CreatePlist "$tempPlist"

su - $(stat -f%Su /dev/console) -c "open /Applications/zoom.us.app"

