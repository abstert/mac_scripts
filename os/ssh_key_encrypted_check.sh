#!/usr/bin/env bash

#set -x

logged_in_user=$(/usr/bin/stat -f%Su /dev/console)
ssh_dir="/Users/$logged_in_user/.ssh"
result_array=()

for key_file in "$ssh_dir"/*; do
    if [[ -f "$key_file" && "$key_file" != *.pub ]]; then
        output=$(/usr/bin/ssh-keygen -y -P "" -f "$key_file" 2>&1)
        #echo "checking... $output"
        if [[ $output =~ "UNPROTECTED PRIVATE KEY FILE" ]]; then
            result_array+=("invld_perm:$key_file")
        elif [[ $output =~ "invalid format" ]]; then
            result_array+=("invld_frmt:$key_file")
        elif [[ $output =~ "incorrect passphrase" ]]; then
            result_array+=("enabled:$key_file")
        else
            #echo "disabled... $output"
            result_array+=("disabled:$key_file")
        fi
    fi
done

#echo "${result_array[@]}"
#echo ""
if [ "${#result_array[*]}" -lt 1 ]; then
    echo "No private keys were found"
    exit 0
fi

for result_text in "${result_array[@]}"; do
    echo "$result_text"
done

