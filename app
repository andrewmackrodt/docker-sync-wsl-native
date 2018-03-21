#!/bin/bash

# Installs the application dependencies.
install_command () {
    local start_exit_code=$(start_command -d)

    exec_command sh -c "
        composer create-project --prefer-dist laravel/laravel laravel
        cd laravel
        composer require barryvdh/laravel-debugbar --dev
        sudo supervisorctl restart app
    "

    if [[ "$start_exit_code" -eq 0 ]]; then
        docker-compose down
    fi
}

#
# DO NOT MODIFY BELOW THIS LINE
#

BASE_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IFS=$'\n' read -rd '' -a COMMAND_LIST <<<"$(perl -ne '/^([a-z_-]+)_command ?\(/ and print "$1\n"' "${BASH_SOURCE[0]}")"

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
    local base_name=$(basename "${BASH_SOURCE[0]}")

    local command
    local text
    local help_text
    local section

    for command in "${COMMAND_LIST[@]}"; do
        text=$(echo -e "$file_contents" \
            | perl -0777 -ne "/^((?:#[^\n]*\n)+)^${command}_command\ ?\(/m and print \$1;" \
            | perl -pe 's/^[#\t ]+|[#\t ]$//g;' -pe 's/[\t\n]| {2,}/ /g;' \
            | perl -pe 's/ +$//;' )
        if [[ "$text" == "" ]]; then
            text="No documentation available."
        fi
        if [[ "$text" =~ ^\[ ]]; then
            section=$(echo "$text" | perl -ne '/^\[([^\n\]]+)\]/ and print $1')
            if [[ "$section" != "" ]]; then
                text=$(echo "$text" | perl -ne '/\] *(.+)/ and print $1')
                help_text="$help_text\n"
                help_text="$help_text\n\033[33m$section:\033[0m"
            fi
        fi
        help_text="$help_text\n  \033[32m${command/_/:}\033[0m\t$text"

    done

    {
        echo -e "\033[32m[$project_name] $base_name\033[0m"
        echo ""
        echo -e "\033[33mUsage:\033[0m"
        echo "  ./$base_name [command=sh] <arguments>"
        if [[ "$(echo -e "$help_text" | tail -n+2 | head -n1 | grep $'\t')" != "" ]]; then
            echo ""
            echo -e "\033[33mCommands:\033[0m"
        fi
        echo -e "$help_text" | column -t -s $'\t' | perl -pe 's/^ {7}+//' | perl -pe "s/(\033\[33m)/\n\1/"
        echo ""
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
        run_command bash -lll
    fi
}

# Starts containers.
start_command () {
    # exit early if the service is already started
    if `docker-compose exec app hostname >/dev/null 2>&1`; then
        return 1
    fi

    if [[ "$OSTYPE" =~ ^darwin ]] || [[ "$(uname -r)" =~ Microsoft ]]; then
        docker-sync start
        docker-compose -f docker-compose-dev.yml -f docker-compose.yml up "$@"
    else
        docker-compose up "$@"
    fi

    return 0
}

# Stops containers.
stop_command () {
    docker-compose down
}

configure_linux() {
    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=.
BASE_PATH_DEST=/opt/project
BUILD_UID=$(id -u)
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
DOCKER_SYNC_STRATEGY=native_linux
DOCKER_SYNC_USERID=$(id -u)
XDEBUG_REMOTE_CONNECT_BACK=0
XDEBUG_REMOTE_HOST=localhost

EOF
    )" > "${DOCKER_PATH}/.env"
}

configure_mac() {
    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=.
BASE_PATH_DEST=/opt/project
BUILD_UID=$(id -u)
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
DOCKER_SYNC_STRATEGY=native_osx
DOCKER_SYNC_USERID=$(id -u)
XDEBUG_REMOTE_CONNECT_BACK=0
XDEBUG_REMOTE_HOST=docker.for.mac.localhost

EOF
    )" > "$BASE_PATH/.env"
}

configure_windows() {
    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=.
BASE_PATH_DEST=/opt/project
BUILD_UID=$(id -u)
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
DOCKER_SYNC_STRATEGY=unison
DOCKER_SYNC_USERID=$(id -u)
XDEBUG_REMOTE_CONNECT_BACK=0
XDEBUG_REMOTE_HOST=docker.for.win.localhost

EOF
    )" > "${BASE_PATH}/.env"
}


#
# Execute the command(s)
#

main () {
    local command=${1/:/_}
    local args=("${@:2}")

    if [[ ! " ${COMMAND_LIST[@]} " =~ " $command " ]]; then
        if [[ "$command" != "" ]]; then
            command=run
            args=("$@")
        else
            command=help
            args=""
        fi
    fi

    "${command}_command" "${args[@]}"
}

pushd "${BASE_PATH}" >/dev/null
main "$@"
popd >/dev/null
