## Add `/run` to .gitignore
##
## import 'res/ssh-docker-connect.just'
##
## $ curl -OLf https://raw.githubusercontent.com/kurganme/utils/main/ssh-docker-connect.just
##

ssh-docker-connect *args:
    @# systemctl --user daemon-reload
    @S={{quote(justfile_directory())}}/run/docker.sock &&\
    U="$(systemd-escape --path \
             --template docker_sock_forward@.service -- "$S")" &&\
    set -- -- ssh -o StreamLocalBindUnlink=yes \
        -o ExitOnForwardFailure=yes \
        -L "$S":/run/docker.sock \
        -T -N "$@" && \
    if [ "${SSH_AUTH_SOCK:-}" ]; then \
        set -- --setenv=SSH_AUTH_SOCK="$SSH_AUTH_SOCK" "$@"; \
    fi && \
    { systemctl --user reset-failed "$U" 2>/dev/null || true; } &&\
    set -- systemd-run --user --property=Restart=always --unit="$U" \
        --description='docker sock forward for '{{quote(args)}} "$@" && \
    mkdir -p run && \
    printf "%q " "$@" && printf '\b\n' && \
    "$@" && \
    while ! docker info >/dev/null 2>&1; do sleep 1 && echo .; done && \
    just show-docker-server-name
    @printf 'DOCKER_HOST=unix://./run/docker.sock\n'
    @printf 'DOCKER_API_VERSION=%s\n' \
        "$(docker version --format='{{{{.Server.APIVersion}}')"
    @printf 'DOCKER_BUILDKIT=1\n'

ssh-docker-disconnect:
    @S={{quote(justfile_directory())}}/run/docker.sock &&\
    U="$(systemd-escape --path \
             --template docker_sock_forward@.service -- "$S")" &&\
    systemctl --user stop "$U"

show-docker-server-name:
    @docker info --format 'Docker server name: {{{{.Name}}'
