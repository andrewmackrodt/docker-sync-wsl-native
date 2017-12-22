#!/bin/bash

# Installs the application dependencies.
install_command () {
    local is_stopped=$(docker-compose ps app | grep -v 'Exit' | grep -q 'docker-php-entrypoint'; echo $?)

    if [[ "$is_stopped" == "1" ]]; then
        start_command
    fi

    docker-compose exec app sh -c "$(cat <<'EOF'
        composer create-project --prefer-dist laravel/laravel laravel
        cd laravel
        composer require barryvdh/laravel-debugbar --dev
        sudo supervisorctl restart app
EOF
    )"

    if [[ "$is_stopped" == "1" ]]; then
        docker-compose down
    fi
}

#
# DO NOT MODIFY BELOW THIS LINE
#

BASE_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IFS=$'\n' read -rd '' -a COMMAND_LIST <<<"$(perl -ne '/^([a-z]+)_command ?\(/ and print "$1\n"' "${BASH_SOURCE[0]}" | sort)"

# Configures the environment.
configure_command () {
    if [[ "$OSTYPE" =~ ^darwin ]]; then
        configure_mac
    elif [[ "$(uname -r)" =~ Microsoft ]]; then
        configure_windows
    else
        configure_linux
    fi
}

# Executes a shell command in a running container, leave arguments empty to enter a new shell.
exec_command () {
    start_command

    if [[ "$1" != "" ]]; then
        docker-compose exec app "$@"
    else
        docker-compose exec app bash -l
    fi
}

# Displays this help text.
help_command () {
    local project_name=$(cd "$(dirname "${BASH_SOURCE[0]}")" && basename $PWD)
    local file_contents=$(<"${BASH_SOURCE[0]}")

    local command
    local text
    local help_text

    for command in "${COMMAND_LIST[@]}"; do
        text=$(echo "$file_contents" \
            | perl -0777 -ne '/((?:^#[^\n]*\n)*)'$command'_command \(/ms and print $1' \
            | perl -0777 -pe 's/\t/ /g' \
            | perl -pe 's/^# ?//' \
            | perl -0777 -pe 's/\n^/\n \t/mg')
        if [[ "$text" == "" ]]; then
            text="No documentation available."
        fi
        help_text="$help_text\n  \033[32m$command\033[0m\t$text"

    done

    {
        echo -e "\033[32m$project_name docker bootstrap\033[0m"
        echo ""
        echo -e "\033[33mUsage:\033[0m"
        echo "  ./$(basename "${BASH_SOURCE[0]}") command [arguments]"
        echo ""
        echo -e "\033[33mAvailable commands:\033[0m"
        echo -e "$help_text" | column -t -s $'\t' | perl -pe 's/^ {7}+//'
    } >&2
}

# Builds the docker containers.
make_command () {
    docker-compose build
}

# Runs a one-off command in a self-removing container.
run_command () {
    docker-compose run --rm app "$@"
}

# Executes a shell command in a self-removing container, leave arguments empty to enter a new shell.
sh_command () {
    if [[ "$1" != "" ]]; then
        run_command bash -lc "$@"
    else
        run_command bash -l
    fi
}

# Starts containers.
start_command () {
    local is_stopped=$(docker-compose ps app | grep -v 'Exit' | grep -q 'docker-php-entrypoint'; echo $?)

    if [[ "$is_stopped" != "0" ]]; then
        echo "Starting the container"

        if [[ "$OSTYPE" =~ ^darwin ]] || [[ "$(uname -r)" =~ Microsoft ]]; then
            docker-sync start
            docker-compose -f docker-compose-dev.yml -f docker-compose.yml up -d
        else
            docker-compose up -d
        fi
    fi
}

configure_linux() {
    echo "Not Implemented" >&2
    exit 1
}

configure_mac() {
    echo "Not Implemented" >&2
    exit 1
}

configure_windows() {
    echo "Adding private key to the docker parent VM"
    docker run -it --rm \
        -e "SSH_PRIVATE_KEY=$(cat "$HOME/.ssh/id_rsa")" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /usr/bin/docker:/usr/bin/docker \
        alpine \
        sh -c "$(cat <<'EOF1'
            docker run -it --rm --privileged \
                -e "SSH_PRIVATE_KEY=$SSH_PRIVATE_KEY" \
                -v /:/host \
                alpine \
                chroot /host sh -c "$(cat <<'EOF2'
                    if [[ ! -f /root/.ssh/id_rsa ]]; then
                        mkdir -p /root/.ssh
                        chmod 700 /root/.ssh
                        echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
                        chmod 600 /root/.ssh/id_rsa
                    fi
EOF2
                )"
EOF1
        )"

    if [[ "$(docker plugin ls | grep vieux/sshfs)" == "" ]]; then
        echo "Installing plugin vieux/sshfs"
        docker plugin install vieux/sshfs sshkey.source=/root/.ssh/
    fi

    local project_name=$(basename $BASE_PATH)
    local volume_name="${project_name}_app_sshfs"
    local mountpoint=$(docker volume inspect "$volume_name" -f '{{.Mountpoint}}' 2>/dev/null | grep -Ev '^$')
    local host_ip=$(ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{ print $1 }')

    if [[ "$mountpoint" != "" ]]; then
        echo "Removing volume $volume_name"
        docker volume rm -f "$volume_name" >/dev/null
    fi

    echo "Creating volume $volume_name"
    docker volume create -d vieux/sshfs \
        -o "sshcmd=${USER}@${host_ip}:${BASE_PATH}" \
        -o "idmap=user,uid=$(id -u),gid=$(id -g),allow_other,IdentityFile=/root/.ssh/id_rsa" \
        "$volume_name" >/dev/null

    mountpoint=$(docker volume inspect "$volume_name" -f '{{.Mountpoint}}' 2>/dev/null)
    plugin_id=$(docker plugin inspect --format '{{.Id}}' vieux/sshfs)

    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=/var/lib/docker/plugins/${plugin_id}/rootfs${mountpoint}
BASE_PATH_DEST=/opt/project
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
DOCKER_COMPOSE_OS_FILENAME=docker-compose.windows.yml
DOCKER_SYNC_APP_SYNC_EXTERNAL=true
DOCKER_SYNC_STRATEGY=unison
DOCKER_SYNC_USERID=$(id -u)
XDEBUG_REMOTE_CONNECT_BACK=0
XDEBUG_REMOTE_HOST=$host_ip

EOF
    )" > "$BASE_PATH/.env"
}

main () {
    local command=$1
    local args="${@:2}"

    if [[ ! " ${COMMAND_LIST[@]} " =~ " $command " ]]; then
        if [[ "$command" != "" ]]; then
            command=sh
            args=$@
        else
            command=help
            args=""
        fi
    fi

    "${command}_command" "$args"
}

main "$@"
