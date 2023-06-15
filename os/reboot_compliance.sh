#!/bin/bash
#
#   Check the last reboot and prompt to restart if more then 30 days
##########################################
#   Variables
##########################################
lastReboot=$(date -jf "%a %b %d %H:%M:%S %Y" "$(sysctl kern.boottime | awk -F'} ' '{print $NF}')" +%s)
maxRebootThreshold=$(date -j -v-30d +%s)
checkInFile="/Library/company/reboot_checkin.txt"

windowType="utility"
title="Security Compliance"
heading="System Requires Reboot"
description="This system has not had a reboot in 30 days.

You are required to restart this computer within 3 days to meet security compliance.  

The system will automatically restart at that time."
iconPath="/Library/Logo/company_logo.png"
button1="Restart Now"
button2="Later"
defaultButton="1"
delayOptions=""
timeout=120
############################################
#  Functions
############################################
Restart() {
    echo "Restart now was selected."
    rm -rf "$checkInFile"
  	shutdown -r now
}

Later() {
    # user selected to take action at a later time
    echo "User chose to not restart at this time."
    Timer
    exit 2
}

Timer() {
    # Check if file exists already and exit if it does
    if [ -e "$checkInFile" ]; then
        return 
    fi
    # File doesn't exist, so let's create it with the deadline
    futurePrompt=$(date -j -v+2d +%s)
    futurePromptReadable=$(date -r "$futurePrompt")
    printf "Setting prompt for future date of %s\n" "$futurePromptReadable"
    printf "%s > %s\n" "$futurePrompt" "$checkInFile"
    echo "$futurePrompt" > "$checkInFile"
}

LastReboot() {
    local lastRebootDate=$(date -r "$lastReboot")
    printf "Last reboot was: %s -- %s\n" "$lastReboot" "$lastRebootDate"
    #echo "Last reboot was: $lastReboot"
    if [ "$lastReboot" -lt "$maxRebootThreshold" ]; then
        return 0
    else
        # Now is the time to prompt
        return 1
    fi
}

TimerCheck() {
    # Get the last time this script ran from the checkinfile
    local threeDayDeferalDate=$(cat "$checkInFile")
    local realDate=$(date -r "$threeDayDeferalDate")
    printf "Deadline Date is: %s - %s\n" "$threeDayDeferalDate" "$realDate"
    local now=$(date +%s)
    # If we have passed the 3 day mark, reboot
    if [[ "$now" -ge "$threeDayDeferalDate" ]]; then
        return 1
    else
        # Now is the time to prompt
        return 0
    fi
}

############################################
#  Main Logic
############################################
# Check if reboot timer file exists
if [ -e "$checkInFile" ]; then
    echo "Check-in file exists"
    TimerCheck
    if [ $? != 0 ]; then
        # Deadline has passed, force the upgrade
        echo "User is past the deadline timeframe and will be forced to restart."
        Restart
        exit 
    fi
fi
# Check the last time the system was restarted
LastReboot
if [ $? != 0 ]; then
    echo "System has not met prompting threshold (30 Days no reboot)."
    exit 0
fi

# System has not been rebooted in some time, prompt the user with a message
response=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper \
-windowType "$windowType" \
-title "$title" \
-heading "$heading" \
-description "$description" \
-icon "$iconPath" \
-button1 "$button1" \
-button2 "$button2" \
-defaultButton "$defaultButton" \
)

echo "Response was: $response"
# Take action based on user's response
if [ "$response" = 0 ]; then
# Button1 was clicked
    Restart
else
    Later
fi
