## SSH_HOST:="ssh-host"
## DOCKER_HOST := "ssh://" + SSH_HOST
## DOCKER_HOST := "unix://" + env('XDG_RUNTIME_DIR', '/tmp') / \
##                "docker_" + SSH_HOST + ".sock"
## DOCKER_API_VERSION := "1.37"
## DOCKER_BUILDKIT := "0"
## import 'res/docker.just'
## $ curl -OL https://github.com/kurganme/misc/
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
build:
    docker compose build {{build_opts}} -- {{services}}

# Create and start containers
up:
    docker compose up {{up_opts}} -- {{services}}

# Stop and remove containers, networks
down:
    docker compose down {{down_opts}} -- {{services}}

# Start services
start:
    docker compose start {{start_opts}} -- {{services}}

# Stop services
stop:
    docker compose stop {{stop_opts}} -- {{services}}

# Restart service containers
restart:
    docker compose restart {{restart_opts}} -- {{services}}

# Removes stopped service containers
rm:
   docker compose rm {{rm_opts}} -- {{services}}

# List containers
ps:
    docker compose ps {{ps_opts}} -- {{services}}

# Display the running processes
top:
    docker compose top {{top_opts}} -- {{services}}

# Display a live stream of container(s) resource usage statistics
stats:
    docker compose stats {{stats_opts}} -- {{services}}

# View output from containers
logs:
    docker compose logs {{logs_opts}} -- {{services}}

# Enter in a running service container
[no-exit-message]
enter:
    @docker compose exec {{enter_opts}} -- "$(\
        if [ "$services" ]; then \
            set -- {{services}}; printf "%s" "$1"; \
        else \
            { docker compose config --services 2>/dev/null ||: ; } | head -1; \
        fi)" /bin/sh -c '\
        cd; [ -x /bin/bash ] && exec /bin/bash -l; exec /bin/sh -l'

# Inspect changes to files or directories on a service container's filesystem
diff:
    @prj_name="$(docker compose config --format json | jq -r .name)" && \
    set -- {{services}}; \
    if [ "$#" -eq 0 ]; then set -- $(docker compose config --services); fi &&\
    for i; do echo >&2 "######## $i"; \
        docker diff {{diff_opts}} "$prj_name"-"$i" | sort -bk2; done

# Launch a generic docker command
docker *args:
    @docker "$@"

# Launch a generic docker compose command
compose *args:
    @docker compose "$@"

# Upload volumes content
push-volumes:
    @prj_name="$(docker compose config --format json | jq -r .name)" && \
    set -- && \
    if [ "$services" ]; then \
        for i in {{services}}; do \
            set -- "$@" -or -wholename "volumes/$i-*"; \
        done; shift; set -- \( "$@" \); fi && \
    find volumes -mindepth 1 -maxdepth 1 -type d "$@" -printf '%f\0' | \
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
