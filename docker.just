## SSH_HOST:="ssh-host"
## DOCKER_HOST := "ssh://" + SSH_HOST
## DOCKER_HOST := "unix://" + env('XDG_RUNTIME_DIR', '/tmp') / \
##                "docker_" + SSH_HOST + ".sock"
## DOCKER_API_VERSION := "1.37"
## DOCKER_BUILDKIT := "0"
##
## import 'res/docker.just'
##
## $ curl -OLf https://raw.githubusercontent.com/kurganme/utils/main/docker.just
##

services := ""

build_opts := ""
up_opts := "--detach --remove-orphans"
down_opts := "--remove-orphans"
start_opts := ""
stop_opts := ""
restart_opts := ""
rm_opts := "--force"
ps_opts := "--all --format 'table {{.Name}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}'"
top_opts := ""
stats_opts := ""
logs_opts := "-f -n " + `tput lines` + " -t"
enter_opts := ""
diff_opts := ""

# Build or rebuild services
[group('docker')]
build:
    docker compose build {{build_opts}} -- {{services}}

# Build or rebuild services in debug mode
[group('docker')]
build-debug:
    BUILDKIT_PROGRESS=plain \
    docker compose build --no-cache {{build_opts}} -- {{services}}

# Create and start containers
[group('docker')]
up:
    docker compose up {{up_opts}} -- {{services}}

# Stop and remove containers, networks
[group('docker')]
down:
    docker compose down {{down_opts}} -- {{services}}

# Start services
[group('docker')]
start:
    docker compose start {{start_opts}} -- {{services}}

# Stop services
[group('docker')]
stop:
    docker compose stop {{stop_opts}} -- {{services}}

# Restart service containers
[group('docker')]
restart:
    docker compose restart {{restart_opts}} -- {{services}}

# Removes stopped service containers
[group('docker')]
rm:
   docker compose rm {{rm_opts}} -- {{services}}

# List containers
[group('docker')]
ps:
    docker compose ps {{ps_opts}} -- {{services}}

# Display the running processes
[group('docker')]
top:
    docker compose top {{top_opts}} -- {{services}}

# Display a live stream of container(s) resource usage statistics
[group('docker')]
stats:
    docker compose stats {{stats_opts}} -- {{services}}

# View output from containers
[group('docker')]
logs:
    docker compose logs {{logs_opts}} -- {{services}}

# Enter in a running service container
[no-exit-message]
[group('docker')]
enter:
    @docker compose exec {{enter_opts}} -- "$(\
        if [ "$services" ]; then \
            set -- {{services}}; printf "%s" "$1"; \
        else \
            { docker compose config --services 2>/dev/null ||: ; } | head -1; \
        fi)" /bin/sh -c '\
        cd; [ -x /bin/bash ] && exec /bin/bash -l; exec /bin/sh -l'

# Inspect changes to files or directories on a service container's filesystem
[group('docker')]
diff:
    @prj_name="$(docker compose config --format json | jq -r .name)" && \
    set -- {{services}}; \
    if [ "$#" -eq 0 ]; then set -- $(docker compose config --services); fi &&\
    for i; do echo >&2 "######## $i"; \
        docker diff {{diff_opts}} "$prj_name"-"$i" | sort -bk2; done

# Launch a generic docker command
[group('docker')]
docker *args:
    @docker "$@"

# Launch a generic docker compose command
[group('docker')]
compose *args:
    @docker compose "$@"

# Upload volumes content
[group('docker')]
push-volumes:
    @prj_name="$(docker compose config --format json | jq -r .name)" && \
    if [ -z "$prj_name" ]; then exit 1; fi && \
    set -- && \
    if [ "$services" ]; then \
        for i in {{services}}; do \
            set -- "$@" -or -wholename "volumes/$i-*"; \
        done; shift; set -- \( "$@" \); fi && \
    find volumes -mindepth 1 -maxdepth 1 -type d "$@" \! -name '.*' -printf '%f\0' | \
    xargs -0I{} -- rsync \
        -via --delete --numeric-ids --rsh `\
            `"/bin/sh -c 'v=\"\$1\" && shift && `\
            `exec docker run --rm -i -v \"\$v\":/mnt `\
            `instrumentisto/rsync-ssh \"\$@\"' -" \
        --exclude '/.mypy_cache' --exclude '/.mypy.ini' \
        --exclude '/Pipfile' --exclude '/Pipfile.lock' \
        --delete-excluded \
        --usermap=:root --groupmap=:root \
        ./volumes/{}/ "$prj_name"-{}:/mnt/
