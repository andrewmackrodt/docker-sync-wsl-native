#!/bin/bash

if [[ `id -u` -gt 0 ]]; then
    sudo /usr/bin/supervisord -c /etc/supervisord.conf
fi

/usr/local/bin/docker-php-entrypoint sh "$@"
