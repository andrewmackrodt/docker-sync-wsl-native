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
        docker-compose up -d
    fi
}

configure_linux() {
    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=.
BASE_PATH_DEST=/opt/project
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
XDEBUG_REMOTE_CONNECT_BACK=1
XDEBUG_REMOTE_HOST=localhost

EOF
    )" > "$BASE_PATH/.env"
}

configure_mac() {
    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=.
BASE_PATH_DEST=/opt/project
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
XDEBUG_REMOTE_CONNECT_BACK=0
XDEBUG_REMOTE_HOST=docker.for.mac.localhost

EOF
    )" > "$BASE_PATH/.env"
}

configure_windows() {
    local host_ip=$(ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{ print $1 }')

    echo "Creating .env file"
    echo "$(cat <<EOF
BASE_PATH_SRC=.
BASE_PATH_DEST=/opt/project
DOCKER_COMPOSE_ENV_FILENAME=docker-compose.dev.yml
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
