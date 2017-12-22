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

if [[ "$(id -u)" != "0" ]]; then
    sudo "${BASH_SOURCE[0]}" $USER
    exit $?
fi

WORKSPACE_USER=$1

if [[ ! -f "/home/${WORKSPACE_USER}/.bashrc" ]]; then
    echo "Invalid user specified" >&2
    exit 1
fi

# start openssh
if [[ "$(ps x | grep '[s]ftp-server')" == "" ]]; then
    service ssh start >/dev/null
fi

# mount the user home directory to /w
if [[ "$(mount | grep 'home on /w type lxfs')" == "" ]] || [[ ! -f /w/.bashrc ]]; then
    mkdir /w 2>/dev/null
    mount --bind "/home/${WORKSPACE_USER}" /w
fi
