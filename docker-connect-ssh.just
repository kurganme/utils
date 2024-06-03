## Add `/run` to .gitignore
##
## import 'res/ssh-docker-connect.just'
##
## $ curl -OLf https://raw.githubusercontent.com/kurganme/utils/main/ssh-docker-connect.just
##

DOCKER_HOST := env("DOCKER_HOST", "unix://./run/docker.sock")

docker-connect-ssh *args:
    @# systemctl --user daemon-reload
    @if [ "${DOCKER_HOST#unix://}" = "$DOCKER_HOST" ]; then \
        printf >&2 'error: bad DOCKER_HOST value\n' && exit 1; fi && \
    S="$(readlink -f {{quote(join(justfile_directory(), \
         trim_start_match(DOCKER_HOST, "unix://")))}})" && \
    U="$(systemd-escape --path --template docker_sock_forward@.service \
                        -- "$S")" && \
    set -- -- ssh -o StreamLocalBindUnlink=yes \
        -o ExitOnForwardFailure=yes \
        -L "$S":/run/docker.sock \
        -T -N "$@" && \
    if [ "${SSH_AUTH_SOCK:-}" ]; then \
        set -- --setenv=SSH_AUTH_SOCK="$SSH_AUTH_SOCK" "$@"; \
    fi && \
    { systemctl --user reset-failed "$U" 2>/dev/null || true; } && \
    set -- systemd-run --user --property=Restart=always --unit="$U" \
        --description='docker sock forward for '{{quote(args)}} "$@" && \
    mkdir -p "$(dirname "$S")" && \
    printf "%q " "$@" && printf '\b\n' && "$@" && \
    while ! docker info >/dev/null 2>&1; do sleep 1 && echo .; done && \
    just docker-show-server-name
    @printf 'DOCKER_HOST=%s\n' "$DOCKER_HOST"
    @printf 'DOCKER_API_VERSION=%s\n' \
        "$(docker version --format='{{{{.Server.APIVersion}}')"
    @printf 'DOCKER_BUILDKIT=1\n'

docker-disconnect-ssh:
    @if [ "${DOCKER_HOST#unix://}" = "$DOCKER_HOST" ]; then \
        printf >&2 'error: bad DOCKER_HOST value\n' && exit 1; fi && \
    S="$(readlink -f {{quote(join(justfile_directory(), \
         trim_start_match(DOCKER_HOST, "unix://")))}})" && \
    U="$(systemd-escape --path --template docker_sock_forward@.service \
                        -- "$S")" && \
    systemctl --user stop "$U"

docker-show-server-name:
    @docker info --format 'Docker server name: {{{{.Name}}'
