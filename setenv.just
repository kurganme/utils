## Add `/.env` to .gitignore
##
## import 'res/setenv.just'
##
## $ curl -OLf https://raw.githubusercontent.com/kurganme/utils/main/setenv.just
##

setenv envname:
    if [ ! -e envs/{{quote(envname)}}.env ]; then \
        echo >&2 'Invalid environment name'; exit 1; fi
    ln -nsf envs/{{quote(envname)}}.env .env
