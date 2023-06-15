#!/bin/bash
#set -x
####################################
#   Microsoft Office 2019 - Updater
#   This script is meant to download and install MS Office from the MS Urls
#   1) Check for existence of MS apps and record
#   2) Check Version and ensure it is the latest
#   3) Remove old or dated app
#   4) Download and Install apps that need upgrading
#############################################################################
#   Variables
#############################################################################
# OfficeSuiteInstaller="https://go.microsoft.com/fwlink/?linkid=525133"

# Dictionary is as follows
# 1) Name of App (ie. Word or Powerpoint)
# 2) Full Name of APp (ie. "Microsoft Word.app")
# 3) Download link for app
ms_Apps_Dict=( \
    "AutoUpdate:/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app:go.microsoft.com/fwlink/?linkid=830196" \
    "Word:Microsoft Word.app:go.microsoft.com/fwlink/?linkid=525134" \
    "Excel:Microsoft Excel.app:go.microsoft.com/fwlink/?linkid=525135" \
    "Outlook:Microsoft Outlook.app:go.microsoft.com/fwlink/?linkid=525137" \
    "PowerPoint:Microsoft PowerPoint.app:go.microsoft.com/fwlink/?linkid=525136" \
    "OneNote:Microsoft OneNote.app:go.microsoft.com/fwlink/?linkid=820886" \
)

#############################################################################
#   Functions
#############################################################################
CheckIfRunning() {
    local appName="$1"
    ps ax | grep "$appName" | grep -v grep > /dev/null
    if [ $? = 0 ]; then
        # App is running, skip installling
        return 1
    fi
    return 0
}

GetVersion() {
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

GetWebVersion() {
    local url="$1"
    local version=$(curl -s -I -L "$url" | grep -i "Content-Disposition" | awk -F'=' '{print $2}' | awk -F'_' '{print $3}' | sed 's/\.//g')
    echo "$version"
}

InstallApplication() {
    local pkgPath="$1"
    printf "MSOFFICE - Installing %s\n" $(basename "$pkgPath")
    /usr/sbin/installer -verbose -pkg "$pkgPath" -target / > /dev/null 2>&1
    installerExitCode=$?
    if [ "$installerExitCode" -ne 0 ]; then
        printf "MSOFFICE - Failed to install: %s\n" "$pkgPath"
        printf "MSOFFICE - Installer exit code: %s\n" "$installerExitCode"
    else
        printf "MSOFFICE - Installed successfully: %s\n" "$pkgPath" 
    fi
}

CheckExistence() {
    local appPath="$1"
	# Checking to see if the app is in the location defined above.
	if [ -e "$appPath" ]; then
		#echo "MSOFFICE - Application $appPath exists."
		return 0
	else
		#echo "MSOFFICE - Application Does Not Exist at $appPath."
		return 1
	fi
}

DownloadApp(){
    local url="$1"
    local downloadUrl=$(curl "$url" -s -L -I -o /dev/null -w '%{url_effective}')
    local pkgName=$(printf "%s" "$downloadUrl" | sed 's@.*/@@')
    local pkgPath="$2/$pkgName"
    CheckExistence "$pkgPath"
    if [ $? = 0 ]; then
        # Remove old or failed downloads
        rm -rf "$pkgPath"
    fi
    #curl --retry 1 --retry-max-time 180 --max-time 180 --fail --silent -L -C - "$downloadUrl" -o "$pkgPath"
    curl --silent -L -C - "$downloadUrl" -o "$pkgPath"
    if [ $? != 0 ]; then
        ExitScript "MSOFFICE - Failed download: $pkgName: $(echo $?)" "1"
    fi
    echo "$pkgPath"
}

ExitScript() {
    local output="$1"
    local exitCode="$2"
    echo "$output"
    exit "$exitCode"
}

#############################################################################
#   Logic
#############################################################################
printf "MSOFFICE - Checking if Office Apps are installed...\n"
for application in "${ms_Apps_Dict[@]}" ; do
    appName=$(echo "$application" | awk -F':' '{print $1}')
    appPath=$(echo "$application" | awk -F':' '{print $2}')
    appUrl=$(echo "https://$(echo $application | awk -F':' '{print $3}')")
    #printf "name: %s\npath: %s\ndownloadUrl: %s\n" "$appName" "$appPath" "$appUrl"
    printf "\nChecking existence for %s\n" "$appPath"
    if [ "$appName" = "AutoUpdate" ]; then
        CheckExistence "$appPath"
        if [ $? != 0 ]; then
            printf "MSOFFICE - %s does not exist on this system" "$appName"
            #continue
        fi
        localVer=$(GetVersion "$appPath/Contents/Info.plist" "CFBundleVersion")
    else
        CheckExistence /Applications/"$appPath"
        if [ $? != 0 ]; then
            printf "MSOFFICE - %s does not exist on this system" "$appName"
            #continue
        fi
        localVer=$(GetVersion /Applications/"$appPath"/Contents/Info.plist "CFBundleVersion")
    fi

    webVer=$(GetWebVersion "$appUrl")
    printf "MSOFFICE - %s is running version: %s\nMSOFFICE - Should be running: %s\n" "$appName" "$localVer" "$webVer"
    if [ $localVer -ge $webVer ]; then
        # Already on current version
        printf "MSOFFICE - Application %s is current, checking next app...\n" "$appName"
        continue
    fi
    # Check if application is runnign and skip if it is
    CheckIfRunning "$appName"
    if [ "$?" != 0 ]; then
        printf "MSOFFICE - Application %s is running and will be skipped for installation\n" "$appName"
        continue
    fi
    printf "MSOFFICE - Need to upgrade %s from url %s, downloading now...\n" "$appName" "$appUrl"
    
    installPath=$(DownloadApp "$appUrl" "/tmp")
    InstallApplication "$installPath"
    rm -rf "$installPath"
done

mau_Path="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"
second_Mau_Path="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/Microsoft AU Daemon.app"
printf "MSOFFICE- Registering Microsoft Auto Update (MAU)"
if [ -e "$mau_Path" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R -f -trusted "$mau_Path"
fi

if [ -e "$second_Mau_Path" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R -f -trusted "$second_Mau_Path"
fi



