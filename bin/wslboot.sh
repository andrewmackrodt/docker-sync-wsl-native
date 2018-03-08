#!/bin/bash

# Installation Instructions:
#
# 1. Start a non-root WSL shell and paste the below command:
#
#    $ echo -e "$USER ALL=(root) NOPASSWD: /usr/local/bin/wslboot.sh" | sudo tee /etc/sudoers.d/wslboot >/dev/null
#
# 2. Copy this file to /usr/local/bin
#
# 3. Make the file executable
#
#    $ chmod a+x

# restart the shell as root
if [[ `id -u` -ne 0 ]]; then
    sudo "${BASH_SOURCE[0]}"
    exec bash -l "$@"
    exit $?
fi

WSL_HOME_DRIVE=w

# sanity check that the sudo user exists in /etc/passwd
if ! `grep -q -E "^${SUDO_USER}" /etc/passwd`; then
    echo "Invalid user specified" >&2
    exit 1
fi

# alias all drives from /mnt to / - this is supported natively in upcoming windows
# https://docs.microsoft.com/en-us/windows/wsl/wsl-config
MOUNTED=`ls -dl /* | awk '($1 == "drwxrwxrwx" || $3 != "root" ) && $9 ~ "/[a-z]$" { print $9 }' | perl -0777 -pe 's/[^a-z]//g'`
IFS=$'\n'
for drive in `ls -dl /mnt/* | awk '$3 == "root" && $9 ~ "/[a-z]$" { print $9 }'`; do
    drive="${drive:5}"
    if [[ ! "${MOUNTED}" =~ $drive ]]; then
        mkdir "/${drive}" 2>/dev/null
        mount --bind "/mnt/${drive}" "/${drive}"
    fi
done

# start openssh
if ! `ps x | grep -q '[s]ftp-server'`; then
    service ssh start >/dev/null
fi

# mount the user home directory to $WSL_HOME_DRIVE
if ! `mount | grep -q "home on "/${WSL_HOME_DRIVE}" type lxfs"`; then
    mkdir "/${WSL_HOME_DRIVE}" 2>/dev/null
    mount --bind "/home/${SUDO_USER}" "/${WSL_HOME_DRIVE}"
fi
