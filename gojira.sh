#!/usr/bin/env bash

# Copyright 2019-2022 Kong Inc.

GOJIRA=$(basename $0)
GOJIRA_PATH=$(dirname $(realpath $0))
DOCKER_PATH=$GOJIRA_PATH/docker
DOCKER_FILE=$DOCKER_PATH/Dockerfile
COMPOSE_FILE=$DOCKER_PATH/docker-compose.yml.sh

# Add gojira extras to env path
PATH=$PATH:$GOJIRA_PATH/extra

GOJIRA_VERSION=0.5.0
GOJIRA_ROARS=(
  "RAWR" "urhghh" "tasty vagrant" "..." "nomnomnom" "beer"
  "\e[1m\e[31ma \e[33mw \e[93me \e[32ms \e[34mo \e[96mm \e[35me \e[0m"
  "\e[38;5;206m❤ \e[0m" "ゴジラ" "Fast Track" "coming to a theater near you"
  "you're breathtaking" "Monster Zero" "Let Me Fight" "Das Governance"
  "Ho-ho-ho!" "Fail fast and furiously" "King of Monsters"
  "the Houdini of the Seas" "From the Core" "a Memento of the Past"
  "An amazing project!" "the Bane of Anthropoids"
)
GOJIRA_BOOMS=(
  "BOOM" "GOT MILK" "U MAD" "LEAVE ONLY BUBBLES"
)

GOJIRA_EGGS=()

globals() {
# Defaults and overloading
GOJIRA_KONGS=${GOJIRA_KONGS:-~/.gojira/kongs}
GOJIRA_HOME=${GOJIRA_HOME:-~/.gojira/home}
# only set GOJIRA_DATABASE if it's explicitly not set (empty means empty)
[[ -z ${GOJIRA_DATABASE+x} ]] && GOJIRA_DATABASE=${GOJIRA_DATABASE:-postgres}
[[ -z ${GOJIRA_REDIS+x} ]] && GOJIRA_REDIS=${GOJIRA_REDIS:-1}
GOJIRA_REPO=${GOJIRA_REPO:-kong}
GOJIRA_TAG=${GOJIRA_TAG:-master}
GOJIRA_GIT_REMOTE=${GOJIRA_GIT_REMOTE:-git@github.com:kong}
GOJIRA_GIT_HTTPS=${GOJIRA_GIT_HTTPS:-0}
GOJIRA_GIT_HTTPS_REMOTE=${GOJIRA_GIT_HTTPS_REMOTE:-https://github.com/kong}
GOJIRA_REDIS_MODE=${GOJIRA_REDIS_MODE:-""}
GOJIRA_CLUSTER_INDEX=${GOJIRA_CLUSTER_INDEX:-1}
GOJIRA_DETACH_UP=${GOJIRA_DETACH_UP:-"--detach"}
# Run gojira in "dev" mode or in "image" mode
GOJIRA_MODE=${GOJIRA_MODE:-dev}
GOJIRA_NETWORK_MODE=${GOJIRA_NETWORK_MODE}
GOJIRA_TARGET=${GOJIRA_TARGET:-kong}
GOJIRA_APT_MIRROR=${GOJIRA_APT_MIRROR:-"none"}

# Feature flags. Use the new cool stuff by default. Set it off to the ancient
# one if it does not work for you
GOJIRA_USE_SNAPSHOT=${GOJIRA_USE_SNAPSHOT:-1}
GOJIRA_DETECT_LOCAL=${GOJIRA_DETECT_LOCAL:-1}
GOJIRA_PIN_LOCAL_TAG=${GOJIRA_PIN_LOCAL_TAG:-1}
GOJIRA_MAGIC_DEV=${GOJIRA_MAGIC_DEV:-0}

_EXTRA_ARGS=()
_GOJIRA_VOLUMES=()
_GOJIRA_PORTS=()
_GOJIRA_CLI_ENVS=()

unset FORCE
unset PREFIX
unset EXTRA_ARGS

# Accept outside GOJIRA_KONG_PATH hardcoded
if [[ -n $GOJIRA_KONG_PATH ]]; then
  GOJIRA_LOC_PATH=1
else
  unset GOJIRA_KONG_PATH
  unset GOJIRA_LOC_PATH
fi

unset GOJIRA_SNAPSHOT
unset GOJIRA_SNAPSHOT_LEVEL
unset GOJIRA_HOSTNAME
unset GOJIRA_VOLUMES
unset GOJIRA_PORTS
unset GOJIRA_TAINTED_LOCAL

unset _RAW_INPUT
}

function warn() {
  >&2 \echo -en "\033[1;33m"
  >&2 echo "WARNING: $*"
  >&2 \echo -en "\033[0m"
}

function err {
  [[ $* =~ ^(\[.*\])(.*) ]] \
    && >&2 echo -e "\033[1;31m${BASH_REMATCH[1]}\033[1;0m${BASH_REMATCH[2]}" \
    || >&2 echo -e "$*"
  exit 1
}

function inf {
  [[ $* =~ ^(\[.*\])(.*) ]] \
    && >&2 echo -e "\033[1;34m${BASH_REMATCH[1]}\033[1;0m${BASH_REMATCH[2]}" \
    || >&2 echo -e "$*"
}

function is_kong_repo {
  local some_kong_sha="ffd70b3101ba38d9acc776038d124f6e2fccac3c"
  git rev-parse --git-dir &> /dev/null
  git cat-file -e "$some_kong_sha^{commit}" &> /dev/null
}

function validate_arguments {
    # check for common errors

    # We are joining a network that has a "db" service and we are
    # adding another "db" service (because we didn't pass --alone).
    # That will make dns requests to "db" to roundrobin between the
    # two, and it's probably not what we want.
    [[ "$ACTION" == "up" ]] && [ -n "$GOJIRA_NETWORK" ] &&
        [ -n "$GOJIRA_DATABASE" ] &&
        docker network inspect $GOJIRA_NETWORK &> /dev/null &&
        docker network inspect $GOJIRA_NETWORK | grep '_db_' 1> /dev/null &&
        warn "Creating a db in a network with db already.
         This might cause to round robin requests to db to multiple dbs. Try --alone flag"

  [[ $GOJIRA_MODE == "image" ]] && [[ -z $GOJIRA_IMAGE ]] && \
    err "To run kong images with gojira you need to specify an image: " \
        "using --image <image name> or setting \$GOJIRA_IMAGE"

  # Disable the fancy stuff is GOJIRA_IMAGE is pre-set
  if [[ -n $GOJIRA_IMAGE ]]; then
    GOJIRA_MAGIC_DEV=0
    GOJIRA_DETECT_LOCAL=0
    if [[ -z $GOJIRA_TAINTED_LOCAL ]]; then
      GOJIRA_MODE="image"
    fi
  fi
}

function cli_envs {
  cat << EOF
version: '3.5'
services:
  ${GOJIRA_TARGET:-kong}:
    environment:
EOF
  for env in "${_GOJIRA_CLI_ENVS[@]}"; do
    cat << EOF
      - $env
EOF
  done
}

function parse_args {
  # Do not parse a starting --help|-h as an action
  # let it fail later. gojira --foo means "no action"
  ! [[ $1 =~ ^- ]] && ACTION=$1 && shift

  # extract @smth from action as a target argument
  # foo@bar -> action foo, target bar
  [[ $ACTION =~ .*\@(.*) ]]
  GOJIRA_TARGET=${BASH_REMATCH[1]:-$GOJIRA_TARGET}

  [[ $GOJIRA_TARGET =~ (.*)\:(.*) ]]
  GOJIRA_TARGET=${BASH_REMATCH[1]:-$GOJIRA_TARGET}
  GOJIRA_CLUSTER_INDEX=${BASH_REMATCH[2]:-$GOJIRA_CLUSTER_INDEX}

  ACTION=${ACTION/%@*}

  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -V|--verbose)
        set -x
        ;;
      -h|--help)
        load_plugins
        usage
        exit 0
        ;;
      -k|--kong)
        GOJIRA_KONG_PATH=$(realpath $2)
        GOJIRA_LOC_PATH=1
        GOJIRA_TAINTED_LOCAL=1
        shift
        ;;
      -t|--tag)
        GOJIRA_TAG=$2
        GOJIRA_TAINTED_LOCAL=1
        shift
        ;;
      -p|--prefix)
        PREFIX=$2
        shift
        ;;
      -pp|--port)
        _GOJIRA_PORTS+=("$2")
        shift
        ;;
      -n|--network)
        GOJIRA_NETWORK=$2
        shift
        ;;
      -v|--volume)
        _GOJIRA_VOLUMES+=("$2")
        shift
        ;;
      -e|--env)
        _GOJIRA_CLI_ENVS+=("$2")
        shift
        ;;
      --postgres)
        GOJIRA_DATABASE=${GOJIRA_DATABASE:+postgres}
        KONG_DATABASE=postgres
        ;;
      --cassandra)
        GOJIRA_DATABASE=${GOJIRA_DATABASE:+cassandra}
        KONG_DATABASE=cassandra
        ;;
      --off)
        GOJIRA_DATABASE=
        KONG_DATABASE=off
        ;;
      --alone)
        GOJIRA_DATABASE=
        GOJIRA_REDIS=
        ;;
      --redis-cluster)
        GOJIRA_REDIS_MODE="cluster"
        ;;
      --image)
        GOJIRA_IMAGE=$2
        shift
        ;;
      --host)
        GOJIRA_HOSTNAME=$2
        shift
        ;;
      -r|--repo)
        GOJIRA_REPO=$2
        GOJIRA_TAINTED_LOCAL=1
        shift
        ;;
      -f|--force)
        FORCE=1
        ;;
      --git-https)
        GOJIRA_GIT_HTTPS=1
        ;;
      --cluster)
        GOJIRA_RUN_CLUSTER=1
        ;;
      --index)
        GOJIRA_CLUSTER_INDEX=$2
        shift
        ;;
      --egg)
        GOJIRA_EGGS+=("$2")
        shift
        ;;
      --network-mode)
        GOJIRA_NETWORK_MODE=$2
        shift
        ;;
      --apt-mirror)
        GOJIRA_APT_MIRROR=$2
        shift
        ;;
      -)
        _EXTRA_ARGS+=("$(cat $2)")
        _RAW_INPUT=1
        shift
        ;;
      --)
        shift
        _EXTRA_ARGS+=("$@")
        break
        ;;
      *)
        _EXTRA_ARGS+=("$1")
        ;;
    esac
    shift
  done

  EXTRA_ARGS="${_EXTRA_ARGS[@]}"
  GOJIRA_PORTS="${_GOJIRA_PORTS[@]}"
  GOJIRA_VOLUMES="${_GOJIRA_VOLUMES[@]}"

  validate_arguments

  # detect if current folder looks like a kong
  # only if no -k, -t, -r has been provided
  if [[ "$GOJIRA_DETECT_LOCAL" == 1 ]]; then
    if [[ -z "$GOJIRA_TAINTED_LOCAL" ]] && is_kong_repo "$PWD" ; then
      GOJIRA_KONG_PATH=$(git rev-parse --show-toplevel)
      GOJIRA_LOC_PATH=1
    fi
  fi

  local components=()

  if [[ -n $PREFIX ]]; then
    components+=("$PREFIX")
  fi

  if [[ $GOJIRA_MODE == "image" ]]; then
    components+=("$(basename "$GOJIRA_IMAGE")")
  elif [[ -n "$GOJIRA_KONG_PATH" ]]; then
    components+=("$(basename $GOJIRA_KONG_PATH)")
    # New behavior, always use the same tag for a local kong path
    if [[ "$GOJIRA_PIN_LOCAL_TAG" == 1 ]] ; then
      # For the time being, use the path to identify this gojira.
      # Caveat: if you move or rename the folder, it will generate a new one
      # 9 characters is enough
      components+=("$(echo "$GOJIRA_KONG_PATH" | sha1sum | awk '{print $1}' | cut -c1-9)")
    else
      # Old behavior. Get tag from repo
      pushd $GOJIRA_KONG_PATH
        components+=("$(git rev-parse --abbrev-ref HEAD)")
      popd
    fi
  else
    components+=("$GOJIRA_REPO")
    components+=("$GOJIRA_TAG")
  fi

  PREFIX=$(IFS="-" ; echo "${components[*]}")
  # Allowed docker image characters / compose container naming
  PREFIX=$(echo $PREFIX | sed "s:[^a-zA-Z0-9_-]:-:g")

  if [[ $GOJIRA_MODE != "image" ]]; then
    GOJIRA_KONG_PATH=${GOJIRA_KONG_PATH:-$GOJIRA_KONGS/$PREFIX}
  fi

  # Add CLI environment flags to Kong instance
  if [[ ${#_GOJIRA_CLI_ENVS} -gt 0 ]]; then
    add_egg cli_envs
  fi

  if [[ $GOJIRA_NETWORK_MODE == "host" ]]; then
    add_egg "$GOJIRA_PATH/extra/host-mode.yml.sh"
  fi

  if [[ $GOJIRA_GIT_HTTPS == 1 ]]; then
    GOJIRA_GIT_REMOTE=$GOJIRA_GIT_HTTPS_REMOTE
  fi
}

function get_envs {
  export GOJIRA_IMAGE
  export GOJIRA_KONG_PATH
  export GOJIRA_NETWORK
  export GOJIRA_NETWORK_MODE
  export GOJIRA_PORTS
  export GOJIRA_VOLUMES
  export GOJIRA_DATABASE
  export KONG_DATABASE
  export GOJIRA_REDIS
  export GOJIRA_REDIS_MODE
  export DOCKER_CTX=$DOCKER_PATH
  export GOJIRA_HOSTNAME
  export GOJIRA_HOME
  export GOJIRA_PREFIX=$PREFIX
  export GOJIRA_TARGET
}


function create_kong {
  [[ $GOJIRA_MODE == "image" ]] && return

  mkdir -p $GOJIRA_KONGS/$PREFIX

  local url=${GOJIRA_KONG_REPO_URL:-$GOJIRA_GIT_REMOTE/$GOJIRA_REPO.git}

  pushd $GOJIRA_KONGS/$PREFIX
    # clone a branch / tag
    git clone -b ${GOJIRA_TAG} $url $PWD || {
      # checkout SHA
      git clone -n $url $PWD
      git checkout $GOJIRA_TAG
    } || {
      rm -rf $GOJIRA_KONGS/$PREFIX
      err "[!] could not clone $url ($GOJIRA_TAG)"
    }
  popd
}

function rawr {
  echo -e ${GOJIRA_ROARS[$RANDOM % ${#GOJIRA_ROARS[@]}]}
}

function boom {
  echo -e ${GOJIRA_BOOMS[$RANDOM % ${#GOJIRA_BOOMS[@]}]}
}

function roar {
  if [[ $(date +%-m) -eq 12 ]]; then
    cat << EOF
   * .    .   *   ___   .    +    .
 .     .   +    /  /  \\   .   .
  + .          / /| - - |         *
       *   .   * | - - - |   *   .
   +     .      |---------|   .  +
EOF
 else
    cat << EOF
                 _,-}}-._
                /\   }  /\\
EOF
  fi
  cat << EOF
               _|(O\\_ _/O)
             _|/  (__''__)
           _|\/    WVVVVW    $(rawr)!
          \ _\     \MMMM/_
        _|\_\     _ '---; \_
   /\   \ _\/      \_   /   \\
  / (    _\/     \   \  |'VVV
 (  '-,._\_.(      'VVV /
  \         /   _) /   _)
   '....--''\__vvv)\__vvv)      ldb
EOF
}


function booom {
cat << EOF
       $(boom)?

    \         .  ./
  \      .:";'.:.."   /
      (M^^.^~~:.'").
-   (/  .    . . \ \)  -
   ((| :. ~ ^  :. .|))
-   (\- |  \ /  |  /)  -
     -\  \     /  /-
       \  \   /  /......
EOF
}


function usage {
cat << EOF

$(roar | sed -e 's/^/           /')

                      Gojira (Godzilla)

Usage: $GOJIRA action [options...]

Options:
  -t,  --tag            git tag to mount kong on (default: $GOJIRA_TAG)
  -p,  --prefix         prefix to use for namespacing
  -k,  --kong           PATH for a kong folder, will ignore tag
  -n,  --network        use network with provided name
  -r,  --repo           repo to clone kong from
  -pp, --port           expose a port for a kong container
  -v,  --volume         add a volume to kong container
  -e,  --env KEY=VAL    add environment variable binding to kong container
  --image               image to use for kong
  --cassandra           use cassandra
  --alone               do not spin up any db
  --redis-cluster       run redis in cluster mode
  --host                specify hostname for kong container
  --git-https           use https to clone repos
  --egg FILE            add a docker-compose configuration file to use
  --network-mode        set docker network mode
  --yml FILE            kong yml file
  --apt-mirror DOMAIN   use customized Ubuntu apt mirror (such as --apt-mirror apt-mirror.example.com)
  -V,  --verbose        echo every command that gets executed
  -h,  --help           display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on \$GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

  build         build a docker image with the specified VERSIONS

  run           run a command on a running kong container.
                Use with --cluster to run the command across all kong nodes.
                Use with --index 4 to run the command on node #4.

  run@s[:i]     run a command on a specified service (node i)
                example: 'gojira run@db psql -U kong'

  shell         get a shell on a running kong container.

  shell@s[:i]   get a shell on a specified service s (node i)
                example: 'gojira shell@db'

  port          get allocated random port for kong
  port@s[:i]    or for a specified service s (node i)
                example: 'gojira port 8000'
                         'gojira port@kong:3 8000'
                         'gojira port@redis 6379'

  watch         watch a file or a pattern for changes and run an action on the
                target container
                example: 'gojira watch kong.yml "kong reload"'
                         'gojira watch "* **/**/*"  "kong reload"'

  cd            cd into a kong prefix repo

  image         show current gojira image

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in \$GOJIRA_KONGS

  lay           create docker-compose file to use with --egg

  snapshot[?!]  make a snapshot of a running gojira

  compose       alias for docker-compose, try: gojira compose help

  roar          print a decorated dinosaur

  logs          follow container logs

  prefix        show prefix for selected gojira

  nuke [-f]     remove all running gojiras. -f for removing all files

  version       show gojira's version number

EOF

for plugin in $GOJIRA_PLUGINS; do
  hash gojira-$plugin-flags &> /dev/null && gojira-$plugin-flags
done

for plugin in $GOJIRA_PLUGINS; do
  hash gojira-$plugin-commands &> /dev/null && gojira-$plugin-commands
done
}


function image_name {
  if [[ -n $GOJIRA_IMAGE ]]; then return; fi

  # No supplied dependency versions
  if [[ -z $LUAROCKS || -z "${OPENSSL}${BORINGSSL}" || -z $OPENRESTY ]]; then
    # No supplied local kong path and kong prefix does not exist
    if [[ -z "$GOJIRA_LOC_PATH" && ! -d "$GOJIRA_KONGS/$PREFIX" ]]; then
      create_kong
    fi
  fi

  # Get dependencies, unless supplied or found
  local req_file="$GOJIRA_KONG_PATH/.requirements"
  local yaml_file="$GOJIRA_KONG_PATH/.travis.yml"

  if [[ -f $req_file ]]; then
    OPENRESTY=${OPENRESTY:-$(req_find $req_file RESTY_VERSION)}
    LUAROCKS=${LUAROCKS:-$(req_find $req_file RESTY_LUAROCKS_VERSION)}
    OPENSSL=${OPENSSL:-$(req_find $req_file RESTY_OPENSSL_VERSION)}
    RESTY_EVENTS=${RESTY_EVENTS:-$(req_find $req_file RESTY_EVENTS_VERSION)}
    BORINGSSL=${BORINGSSL:-$(req_find $req_file RESTY_BORINGSSL_VERSION)}
    KONG_NGX_MODULE=${KONG_NGX_MODULE:-$(req_find $req_file KONG_NGINX_MODULE_BRANCH)}
    KONG_BUILD_TOOLS=${KONG_BUILD_TOOLS_BRANCH:-$(req_find $req_file KONG_BUILD_TOOLS_BRANCH)}
    KONG_GO_PLUGINSERVER=${KONG_GO_PLUGINSERVER_VERSION:-$(req_find $req_file KONG_GO_PLUGINSERVER_VERSION)}
    KONG_LIBGMP=${GMP_VERSION:-$(req_find $req_file KONG_GMP_VERSION)}
    KONG_LIBNETTLE=${NETTLE_VERSION:-$(req_find $req_file KONG_DEP_NETTLE_VERSION)}
    KONG_LIBJQ=${JQ_VERSION:-$(req_find $req_file KONG_DEP_LIBJQ_VERSION)}
    RESTY_LMDB=${RESTY_LMDB:-$(req_find $req_file RESTY_LMDB_VERSION)}
    RESTY_WEBSOCKET=${RESTY_WEBSOCKET:-$(req_find $req_file RESTY_WEBSOCKET_VERSION)}
    ATC_ROUTER=${ATC_ROUTER:-$(req_find $req_file ATC_ROUTER_VERSION)}
  fi

  if [[ -f $yaml_file ]]; then
    OPENRESTY=${OPENRESTY:-$(yaml_find $yaml_file OPENRESTY)}
    LUAROCKS=${LUAROCKS:-$(yaml_find $yaml_file LUAROCKS)}
    OPENSSL=${OPENSSL:-$(yaml_find $yaml_file OPENSSL)}
    RESTY_LMDB=${RESTY_LMDB:-$(yaml_find $yaml_file RESTY_LMDB)}
    RESTY_EVENTS=${RESTY_EVENTS:-$(yaml_find $yaml_file RESTY_EVENTS_VERSION)}
    RESTY_WEBSOCKET=${RESTY_WEBSOCKET:-$(yaml_find $yaml_file RESTY_WEBSOCKET_VERSION)}
    ATC_ROUTER=${ATC_ROUTER:-$(yaml_find $yaml_file ATC_ROUTER_VERSION)}
    BORINGSSL=${BORINGSSL:-$(yaml_find $yaml_file BORINGSSL)}
  fi

  if [[ -z $LUAROCKS || -z "${OPENSSL}${BORINGSSL}" || -z $OPENRESTY ]]; then
    err "${GOJIRA}: Could not guess version dependencies in" \
        "$req_file or $yaml_file. " \
        "Specify versions as LUAROCKS, OPENSSL/BORINGSSL, and OPENRESTY envs"
  fi

  KONG_NGX_MODULE=${KONG_NGX_MODULE:-master}
  KONG_BUILD_TOOLS=${KONG_BUILD_TOOLS:-master}

  ssl_provider="openssl-$OPENSSL"
  if [[ -n $BORINGSSL ]]; then
    ssl_provider="boriongssl-$BORINGSSL"
  fi

  local components=(
    "luarocks-$LUAROCKS"
    "openresty-${OPENRESTY}"
    "$ssl_provider"
    "knm-$KONG_NGX_MODULE"
    "kbt-$KONG_BUILD_TOOLS"
  )
  if [[ -n "$KONG_GO_PLUGINSERVER" ]]; then
    GO_VERSION=${GO_VERSION:-1.13.12}
    components+=(
      "go-$GO_VERSION"
      "gps-$KONG_GO_PLUGINSERVER"
    )
  fi
  if [[ -n "$KONG_LIBGMP" ]]; then
    components+=(
      "libgmp-$KONG_LIBGMP"
    )
  fi
  if [[ -n "$KONG_LIBNETTLE" ]]; then
    components+=(
      "libnettle-$KONG_LIBNETTLE"
    )
  fi
  if [[ -n "$KONG_LIBJQ" ]]; then
    components+=(
      "libjq-$KONG_LIBJQ"
    )
  fi
  if [[ -n "$RESTY_LMDB" ]]; then
    components+=(
      "resty-lmdb-$RESTY_LMDB"
    )
  fi
  if [[ -n "$RESTY_EVENTS" ]]; then
    components+=(
      "resty-events-${RESTY_EVENTS}"
    )
  fi
  if [[ -n "$RESTY_WEBSOCKET" ]]; then
    components+=(
      "resty-websocket-${RESTY_WEBSOCKET}"
    )
  fi
  if [[ -n "$ATC_ROUTER" ]]; then
    components+=(
      "atc-router-${ATC_ROUTER}"
    )
  fi
  if [[ -n "$BORINGSSL" ]]; then
    components+=(
      "boring-ssl-${$BORINGSSL}"
    )
  fi

  read -r components_sha rest <<<"$(IFS="-" ; echo -n "${components[*]}" | sha1sum)"
  GOJIRA_IMAGE=gojira:$components_sha
}


function build {
  image_name

  BUILD_ARGS=(
    "--build-arg LUAROCKS=$LUAROCKS"
    "--label LUAROCKS=$LUAROCKS"
    "--build-arg OPENSSL=$OPENSSL"
    "--label OPENSSL=$OPENSSL"
    "--build-arg BORINGSSL=$BORINGSSL"
    "--label BORINGSSL=$BORINGSSL"
    "--build-arg OPENRESTY=$OPENRESTY"
    "--label OPENRESTY=$OPENRESTY"
    "--build-arg KONG_NGX_MODULE=$KONG_NGX_MODULE"
    "--label KONG_NGX_MODULE=$KONG_NGX_MODULE"
    "--build-arg KONG_BUILD_TOOLS=$KONG_BUILD_TOOLS"
    "--label KONG_BUILD_TOOLS=$KONG_BUILD_TOOLS"
    "--build-arg APT_MIRROR=$GOJIRA_APT_MIRROR"
  )

  ssl_provider=" * OpenSSL:     $OPENSSL  "
  if [[ -n $BORINGSSL ]]; then
    ssl_provider=" * BoringSSL:   $BORINGSSL  "
  fi

  >&2 echo "Building $GOJIRA_IMAGE"
  >&2 echo ""
  >&2 echo "       Version info"
  >&2 echo "=========================="
  >&2 echo "$ssl_provider"
  >&2 echo " * OpenResty:   $OPENRESTY"
  >&2 echo " * LuaRocks:    $LUAROCKS "
  >&2 echo " * Kong NM:     $KONG_NGX_MODULE"
  >&2 echo " * Kong BT:     $KONG_BUILD_TOOLS"

  if [[ -n "$ATC_ROUTER" ]]; then
    BUILD_ARGS+=(
      "--build-arg ATC_ROUTER=$ATC_ROUTER"
      "--label ATC_ROUTER=$ATC_ROUTER"
    )
    >&2 echo " * ATC ROUTER:  $ATC_ROUTER"
  fi
  if [[ -n "$RESTY_WEBSOCKET" ]]; then
    BUILD_ARGS+=(
      "--build-arg RESTY_WEBSOCKET=$RESTY_WEBSOCKET"
      "--label RESTY_WEBSOCKET=$RESTY_WEBSOCKET"
    )
    >&2 echo " * Resty WEBSOCKET:  $RESTY_WEBSOCKET"
  fi
  if [[ -n "$RESTY_LMDB" ]]; then
    BUILD_ARGS+=(
      "--build-arg RESTY_LMDB=$RESTY_LMDB"
      "--label RESTY_LMDB=$RESTY_LMDB"
    )
    >&2 echo " * Resty LMDB:  $RESTY_LMDB"
  fi
  if [[ -n "$RESTY_EVENTS" ]]; then
    BUILD_ARGS+=(
      "--build-arg RESTY_EVENTS=$RESTY_EVENTS"
      "--label RESTY_EVENTS=$RESTY_EVENTS"
    )
    >&2 echo " * Resty Events:  $RESTY_EVENTS"
  fi
  if [[ -n "$KONG_GO_PLUGINSERVER" ]]; then
    BUILD_ARGS+=(
      "--build-arg GO_VERSION=$GO_VERSION"
      "--label GO_VERSION=$GO_VERSION"
      "--build-arg KONG_GO_PLUGINSERVER=$KONG_GO_PLUGINSERVER"
      "--label KONG_GO_PLUGINSERVER=$KONG_GO_PLUGINSERVER"
    )
    >&2 echo " * Go:          $GO_VERSION"
    >&2 echo " * Kong GPS:    $KONG_GO_PLUGINSERVER"
  fi
  if [[ -n "$KONG_LIBGMP" ]]; then
    BUILD_ARGS+=(
      "--build-arg KONG_LIBGMP=$KONG_LIBGMP"
      "--label KONG_LIBGMP=$KONG_LIBGMP"
    )
    >&2 echo " * libgmp:      $KONG_LIBGMP"
  fi
  if [[ -n "$KONG_LIBNETTLE" ]]; then
    BUILD_ARGS+=(
      "--build-arg KONG_LIBNETTLE=$KONG_LIBNETTLE"
      "--label KONG_LIBNETTLE=$KONG_LIBNETTLE"
    )
    >&2 echo " * libnettle:   $KONG_LIBNETTLE"
  fi
  if [[ -n "$KONG_LIBJQ" ]]; then
    BUILD_ARGS+=(
      "--build-arg KONG_LIBJQ=$KONG_LIBJQ"
      "--label KONG_LIBJQ=$KONG_LIBJQ"
    )
    >&2 echo " * libjq:       $KONG_LIBJQ"
  fi
  >&2 echo "=========================="
  >&2 echo ""

  docker build -f $DOCKER_FILE -t $GOJIRA_IMAGE ${BUILD_ARGS[*]} $DOCKER_PATH
}


function yaml_find {
  cat $1 | grep $2 | head -n 1 | sed 's/.*=//'
}


function req_find {
  grep $2 $1 | head -n 1 | sed 's/.*=//'
}


function executable {
  # it's a file
  if [[ -f $1 ]]; then
    # can be executed
    if [[ -x $1 ]]; then
      return 0
    else
      return 1
    fi
  # It's something we can execute
  elif hash $1; then
    return 0
  else
    return 1
  fi
}


function cleanup {
  local pids=`jobs -p`
  if [[ "$pids" != "" ]]; then
    kill $pids
  fi
}


function p_compose {
  local res
  get_envs

  local flags=()

  local tmps=()

  for egg in "${GOJIRA_EGGS[@]}"; do
    # Have not found an alternative to this that does not involve a potential
    # dangerous eval
    if executable $egg; then
      tfile=$(mktemp -u) && mkfifo "$tfile" || err "[!] Could not create FIFO"
      $egg > $tfile &
      tmps+=("$tfile")
      flags+=("-f $tfile")
    else
      flags+=("-f $egg")
    fi
  done

  docker-compose -f <($COMPOSE_FILE) ${flags[*]} -p $PREFIX "$@"
  res=$?

  rm -f "${tmps[@]}"
  return $res
}


function query_image {
  [[ ! -z $(query_sha $1) ]] || return 1
  echo $1
}

function query_sha {
  local image_sha=$(docker images "--filter=reference=$1" -q)
  [[ ! -z $image_sha ]] || return 1
  echo $image_sha
}


function snapshot_image_name {
  if [[ ! -z $1 ]]; then GOJIRA_SNAPSHOT=$1; return; fi
  image_name
  local sha
  local base_sha=$(query_sha $GOJIRA_IMAGE)

  GOJIRA_BASE_SNAPSHOT=gojira:base-snap-$base_sha

  if [[ -n $GOJIRA_KONG_PATH ]]; then
    pushd $GOJIRA_KONG_PATH
      sha=$(git hash-object kong-*.rockspec)
    popd
    sha=$(echo $base_sha:$sha | sha1sum | awk '{printf $1}')
    GOJIRA_SNAPSHOT=gojira:snap-$sha
  fi
}


function magic_dev {
  if [[ $GOJIRA_MODE != "dev" ]]; then return; fi

  # lvl 0: no snapshot
  if [[ $GOJIRA_SNAPSHOT_LEVEL -lt 2 ]]; then
    inf "[magic dev] running 'make dev'"
    run_command $GOJIRA_TARGET 1 "make dev"
    [[ $? == 0 ]] || err "[magic dev] failed running 'make dev'"
  fi

  if [[ $GOJIRA_USE_SNAPSHOT == 1 ]]; then
    # Only snapshot if snapshot level was 0 to not pile up snapshots
    if [[ $GOJIRA_SNAPSHOT_LEVEL == 0 ]]; then
      inf "[magic dev] snap! snap!"
      snapshot
    fi
  fi
}


function set_snapshot_image_name {
  # lvl 2: good snapshot
  # lvl 1: base snapshot only
  # lvl 0: no snapshot
  if [[ ! -z $(query_image $GOJIRA_SNAPSHOT) ]]; then
    GOJIRA_IMAGE=$GOJIRA_SNAPSHOT
    GOJIRA_SNAPSHOT_LEVEL=2
  elif [[ ! -z $(query_image $GOJIRA_BASE_SNAPSHOT) ]]; then
    GOJIRA_IMAGE=$GOJIRA_BASE_SNAPSHOT
    GOJIRA_SNAPSHOT_LEVEL=1
  else
    GOJIRA_SNAPSHOT_LEVEL=0
  fi
}


function setup {
  mkdir -p $GOJIRA_KONGS
  mkdir -p $GOJIRA_HOME

  [ -d $GOJIRA_HOME ] || cp -r $DOCKER_PATH/home_template $GOJIRA_HOME
  # Ideally we figure out when we need to have a GOJIRA_KONG_PATH or not
  # so we can create it from here.
}

function snapshot {
  local c_id=$(p_compose ps -q $GOJIRA_TARGET)
  if [[ -n $GOJIRA_BASE_SNAPSHOT ]]; then
    docker commit $c_id $GOJIRA_BASE_SNAPSHOT || exit 1
    >&2 echo "Created base snapshot: $GOJIRA_BASE_SNAPSHOT"
  fi
  if [[ -n $GOJIRA_SNAPSHOT ]]; then
    docker commit $c_id $GOJIRA_SNAPSHOT || exit 1
    >&2 echo "Created snapshot: $GOJIRA_SNAPSHOT"
  fi
}

function run_command {
  local where=$1
  # Default node is 1
  local nodes=${2:-1}
  local args=$3

  if [[ -z $args ]]; then
    if [[ ! -z $_RAW_INPUT ]]; then
      args=$EXTRA_ARGS
    else
      # https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
      args=${_EXTRA_ARGS[@]@Q}
    fi
  fi

  # Remove arguments not allowed by exec
  args=$(echo $args | sed "s:'*--scale[ \t']*[a-zA-Z0-9_.-]*=[0-9]*'*::g")

  if [[ -n $GOJIRA_RUN_CLUSTER ]]; then
    nodes=$(p_compose ps | awk '{ print $1 }' | grep -c "${where}_[0-9]*$")
    nodes=$(seq 1 "$nodes")
  fi

  # aggregate any specified environment variable arguments to be passed
  local opt_envvars=${_GOJIRA_CLI_ENVS[*]/#/"--env "}

  local res=0
  for i in $nodes; do
    if [[ -n $GOJIRA_RUN_CLUSTER ]] || [[ $2 != 1 ]]; then
      >&2 echo -en "\033[1;34m[${where}_$i]\033[00m "
    fi

    if [[ -t 1 ]]; then
      p_compose exec $opt_envvars --index "$i" "$where" sh -l -i -c "$args"
    else
      p_compose exec $opt_envvars --index "$i" -T "$where" sh -l -c "$args"
    fi

    # Accumulate exit codes into res
    res=$((res + $?))
  done

  # Return accumulated exit code :) > 0 --> error
  return $res
}

load_plugins() {
  if [[ -z $_GOJIRA_PLUGINS_LOADED ]]; then
    for plugin in $GOJIRA_PLUGINS; do
      ! hash gojira-$plugin &> /dev/null && \
        warn "[plugins] gojira-$plugin not found" && continue
      source "gojira-$plugin" "plugin"
    done

    # XXX hack for  default plugins idk
    source "gojira-yml" "plugin"

    # Make sure we do not source them again ( XXX? )
    export _GOJIRA_PLUGINS_LOADED=1
  fi
}

add_egg() {
  GOJIRA_EGGS+=("$@")
}

main() {

  globals

  parse_args "$@"
  setup

  load_plugins

  case $ACTION in
  help)
    usage
    ;;
  up)
    # kong path does not exist. This means we are upping a build that came
    # with no auto deps, most probably
    if [[ ! -d "$GOJIRA_KONG_PATH" ]]; then create_kong; fi

    if [[ -z $GOJIRA_IMAGE ]]; then
      build || exit 1
    fi

    if [[ "$GOJIRA_USE_SNAPSHOT" == 1 ]]; then
      snapshot_image_name
      set_snapshot_image_name

      # Bring base image up to date man!
      [[ "$GOJIRA_SNAPSHOT_LEVEL" == 1 ]] &&
        warn "Your snapshot is not up to date, bringing up your latest" \
             "compatible base, but remember to run 'make dev'!"
    fi

    p_compose up $GOJIRA_DETACH_UP $EXTRA_ARGS || exit 1

    if [[ $GOJIRA_MAGIC_DEV == 1 ]]; then
      magic_dev
    fi
    ;;
  down)
    p_compose kill
    p_compose down -v
    ;;
  shell)
    local cmd="sh -l -i"
    [[ $GOJIRA_TARGET =~ kong(-[cd]p)? ]] && cmd="gosh -l -i"
    run_command "$GOJIRA_TARGET" "$GOJIRA_CLUSTER_INDEX" "$cmd"
    ;;
  build)
    build
    ;;
  cd)
    if [[ ! -d "$GOJIRA_KONG_PATH" ]]; then create_kong; fi
    echo $GOJIRA_KONG_PATH
    cd $GOJIRA_KONG_PATH 2> /dev/null
    ;;
  run)
    run_command $GOJIRA_TARGET $GOJIRA_CLUSTER_INDEX
    ;;
  images)
    docker images --filter=reference='gojira*' $EXTRA_ARGS
    ;;
  image)
    image_name 2> /dev/null
    echo $GOJIRA_IMAGE
    ;;
  image\?)
    image_name 2> /dev/null
    query_image $GOJIRA_IMAGE || exit 1
    ;;
  image\!)
    image_name 2> /dev/null
    docker rmi $GOJIRA_IMAGE || exit 1
    ;;
  ps)
    docker ps --filter "label=com.konghq.gojira" $EXTRA_ARGS
    ;;
  ls)
    ls -1 $EXTRA_ARGS $GOJIRA_KONGS
    ;;
  compose)
    image_name
    if [[ "$GOJIRA_USE_SNAPSHOT" == 1 ]]; then
      snapshot_image_name
      set_snapshot_image_name
    fi
    p_compose $EXTRA_ARGS
    ;;
  snapshot)
    snapshot_image_name $EXTRA_ARGS
    snapshot $EXTRA_ARGS
    ;;
  snapshot\?)
    snapshot_image_name $EXTRA_ARGS
    query_image $GOJIRA_SNAPSHOT || err "$GOJIRA_SNAPSHOT not found"
    ;;
  snapshot\?\?)
    snapshot_image_name
    query_image $GOJIRA_BASE_SNAPSHOT || err "$GOJIRA_BASE_SNAPSHOT not found"
    ;;
  snapshot\!)
    snapshot_image_name $EXTRA_ARGS
    query_image $GOJIRA_SNAPSHOT && docker rmi $GOJIRA_SNAPSHOT
    ;;
  snapshot\!\!)
    snapshot_image_name
    query_image $GOJIRA_SNAPSHOT && docker rmi $GOJIRA_SNAPSHOT
    query_image $GOJIRA_BASE_SNAPSHOT && docker rmi $GOJIRA_BASE_SNAPSHOT
    ;;
  logs)
    p_compose logs -f --tail=100 $EXTRA_ARGS
    ;;
  roar)
      if [[ $(($RANDOM % 5)) -eq "0" ]] ; then
          echo; paste <(echo "$(booom)") <($0 roar) | expand -t30
      else
          echo; roar; echo
      fi
    ;;
  lay)
    image_name
    if [[ "$GOJIRA_USE_SNAPSHOT" == 1 ]]; then
      snapshot_image_name
      set_snapshot_image_name
    fi
    p_compose config $EXTRA_ARGS
    ;;
  port|ports)
    p_compose port --index "$GOJIRA_CLUSTER_INDEX" "$GOJIRA_TARGET" $EXTRA_ARGS
    ;;
  version)
    echo $GOJIRA $GOJIRA_VERSION ${GOJIRA_ROARS[-1]}
    ;;
  prefix)
    echo $PREFIX
    ;;
  nuke)
    # Do not show docker rm error when there's nothing

    local stuff=$($0 ps -aq $EXTRA_ARGS)
    [[ -n $stuff ]] && docker rm -fv $stuff
    docker network prune -f
    [ -n "$FORCE" ] && rm -fr $GOJIRA_KONGS/* ;
    echo; (booom | sed -e 's/^/          /'); echo
    ;;
  *)
    if ! hash gojira-$ACTION &> /dev/null; then
      usage
      exit 1
    fi
    shift; source gojira-$ACTION
    ;;
  esac
}

pushd() { builtin pushd $1 > /dev/null; }
popd() { builtin popd > /dev/null; }

main "$@"
exit_status=$?
cleanup   # make sure we clean up
exit $exit_status
