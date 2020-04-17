#!/usr/bin/env bash

GOJIRA=$(basename $0)
GOJIRA_PATH=$(dirname $(realpath $0))
DOCKER_PATH=$GOJIRA_PATH/docker
DOCKER_FILE=$DOCKER_PATH/Dockerfile
COMPOSE_FILE=$DOCKER_PATH/docker-compose.yml.sh

GOJIRA_VERSION=0.2.8
GOJIRA_ROARS=(
  "RAWR" "urhghh" "tasty vagrant" "..." "nomnomnom" "beer"
  "\e[1m\e[31ma \e[33mw \e[93me \e[32ms \e[34mo \e[96mm \e[35me \e[0m"
  "\e[38;5;206m❤ \e[0m" "ゴジラ" "Fast Track" "coming to a theater near you"
  "you're breathtaking" "Monster Zero" "Let Me Fight" "Das Governance"
  "Ho-ho-ho!" "Fail fast and furiously" "King of Monsters"
)

# Defaults
GOJIRA_KONGS=${GOJIRA_KONGS:-~/.gojira-kongs}
GOJIRA_HOME=${GOJIRA_HOME:-$GOJIRA_KONGS/.gojira-home/}
GOJIRA_DATABASE=postgres
GOJIRA_REPO=${GOJIRA_REPO:-kong}
GOJIRA_TAG=${GOJIRA_TAG:-master}
GOJIRA_GIT_HTTPS=${GOJIRA_GIT_HTTPS:-0}
GOJIRA_REDIS_MODE=""
GOJIRA_SHELL=${GOJIRA_SHELL:-"bash"}
GOJIRA_CLUSTER_INDEX=${GOJIRA_CLUSTER_INDEX:-1}

# Feature flags. Use the new cool stuff by default. Set it off to the ancient
# one if it does not work for you
GOJIRA_USE_SNAPSHOT=${GOJIRA_USE_SNAPSHOT:-1}
GOJIRA_DETECT_LOCAL=${GOJIRA_DETECT_LOCAL:-1}
GOJIRA_PIN_LOCAL_TAG=${GOJIRA_PIN_LOCAL_TAG:-1}
GOJIRA_MAGIC_DEV=${GOJIRA_MAGIC_DEV:-0}

_EXTRA_ARGS=()
_GOJIRA_VOLUMES=()
_GOJIRA_PORTS=()

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
unset GOJIRA_HOSTNAME
unset GOJIRA_VOLUMES
unset GOJIRA_PORTS
unset GOJIRA_TAINTED_LOCAL

unset _RAW_INPUT

function warn() {
  >&2 \echo -en "\033[1;33m"
  >&2 echo "WARNING: $*"
  >&2 \echo -en "\033[0m"
}

function err {
  >&2 echo "$*"
  exit 1
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
    [ -n "$GOJIRA_NETWORK" ] &&
        [ -n "$GOJIRA_DATABASE" ] &&
        docker network inspect $GOJIRA_NETWORK &> /dev/null &&
        docker network inspect $GOJIRA_NETWORK |
            jq '.[0].Containers[].Name' |
            grep '_db_' 1>/dev/null &&
        warn "Creating a db in a network with db already.
         This might cause to round robin requests to db to multiple dbs. Try --alone flag"
}

function parse_args {
  ACTION=$1
  shift

  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -V|--verbose)
        set -x
        ;;
      -h|--help)
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
      --cassandra)
        GOJIRA_DATABASE=cassandra
        ;;
      --alone)
        GOJIRA_DATABASE=
        ;;
      --redis-cluster)
        GOJIRA_REDIS_MODE="cluster"
        shift
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
      --use-shell)
        GOJIRA_SHELL=$2
        shift
        ;;
      --cluster)
        GOJIRA_RUN_CLUSTER=1
        ;;
      --index)
        GOJIRA_CLUSTER_INDEX=$2
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

  # kong path supplied, override repo / tag
  if [[ -n "$GOJIRA_KONG_PATH" ]]; then
    GOJIRA_REPO=$(basename $GOJIRA_KONG_PATH)
    # New behavior, always use the same tag for a local kong path
    if [[ "$GOJIRA_PIN_LOCAL_TAG" == 1 ]] ; then
      # For the time being, use the path to identify this gojira.
      # Caveat: if you move or rename the folder, it will generate a new one
      GOJIRA_TAG=$(echo "$GOJIRA_KONG_PATH" | sha1sum | awk '{print $1}')
      # 9 characters is enough
      GOJIRA_TAG=${GOJIRA_TAG:0:9}
    else
      # Old behavior. Get tag from repo
      pushd $GOJIRA_KONG_PATH
        GOJIRA_TAG=$(git rev-parse --abbrev-ref HEAD)
      popd
    fi
  fi

  if [ -n "$PREFIX" ]; then
    PREFIX=$PREFIX-$GOJIRA_REPO-$GOJIRA_TAG
  else
    PREFIX=$GOJIRA_REPO-$GOJIRA_TAG
  fi

  # Allowed docker image characters / compose container naming
  PREFIX=$(echo $PREFIX | sed "s:[^a-zA-Z0-9_.-]:-:g")

  GOJIRA_KONG_PATH=${GOJIRA_KONG_PATH:-$GOJIRA_KONGS/$PREFIX}
}

function get_envs {
  export GOJIRA_IMAGE
  export GOJIRA_KONG_PATH
  export GOJIRA_NETWORK
  export GOJIRA_PORTS
  export GOJIRA_VOLUMES
  export GOJIRA_DATABASE
  export GOJIRA_REDIS_MODE
  export DOCKER_CTX=$DOCKER_PATH
  export GOJIRA_HOSTNAME
  export GOJIRA_HOME
  export GOJIRA_PREFIX=$PREFIX
}


function create_kong {
  mkdir -p $GOJIRA_KONGS
  pushd $GOJIRA_KONGS
    local $remote
    if [[ "$GOJIRA_GIT_HTTPS" = 1 ]]; then
      remote="https://github.com/kong"
    else
      remote="git@github.com:kong"
    fi
    git clone -b ${GOJIRA_TAG} $remote/$GOJIRA_REPO.git $PREFIX || exit
  popd
}

function rawr {
  echo -e ${GOJIRA_ROARS[$RANDOM % ${#GOJIRA_ROARS[@]}]}
}


function roar {
  if [[ $(date +%m) -eq 12 ]]; then
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
  -t,  --tag            git tag to mount kong on (default: master)
  -p,  --prefix         prefix to use for namespacing
  -k,  --kong           PATH for a kong folder, will ignore tag
  -n,  --network        use network with provided name
  -r,  --repo           repo to clone kong from
  -pp, --port           expose a port for a kong container
  -v,  --volume         add a volume to kong container
  --image               image to use for kong
  --cassandra           use cassandra
  --alone               do not spin up any db
  --redis-cluster       run redis in cluster mode
  --host                specify hostname for kong container
  --git-https           use https to clone repos
  --use-shell           specify shell for run and shell commands (bash|ash|sh)
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

  run@ [serv]   run a command on a specified service.
                Use with --cluster to run the command across all nodes.
                Use with --index 4 to run the command on node #4
                example: 'gojira run@ db psql -U kong'

  shell         get a shell on a running container

  cd            cd into a kong prefix repo

  image         show current gojira image

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in \$GOJIRA_KONGS

  snapshot      make a snapshot of a running gojira

  compose       alias for docker-compose, try: gojira compose help

  roar          make gojira go all gawo wowo

  logs          follow container logs

  nuke [-f]     remove all running gojiras. -f for removing all files

EOF
}


function image_name {
  # No supplied dependency versions
  if [[ -z $LUAROCKS || -z $OPENSSL || -z $OPENRESTY ]]; then
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
    KONG_NGX_MODULE=${KONG_NGX_MODULE:-$(req_find $req_file KONG_NGINX_MODULE_BRANCH)}
    KONG_BUILD_TOOLS=${KONG_BUILD_TOOLS_BRANCH:-$(req_find $req_file KONG_BUILD_TOOLS_BRANCH)}
  fi

  if [[ -f $yaml_file ]]; then
    OPENRESTY=${OPENRESTY:-$(yaml_find $yaml_file OPENRESTY)}
    LUAROCKS=${LUAROCKS:-$(yaml_find $yaml_file LUAROCKS)}
    OPENSSL=${OPENSSL:-$(yaml_find $yaml_file OPENSSL)}
  fi

  if [[ -z $LUAROCKS || -z $OPENSSL || -z $OPENRESTY ]]; then
    err "${GOJIRA}: Could not guess version dependencies in" \
        "$req_file or $yaml_file. " \
        "Specify versions as LUAROCKS, OPENSSL, and OPENRESTY envs"
  fi

  KONG_NGX_MODULE=${KONG_NGX_MODULE:-master}
  KONG_BUILD_TOOLS=${KONG_BUILD_TOOLS:-master}

  local components=(
    "luarocks-$LUAROCKS"
    "openresty-${OPENRESTY}"
    "openssl-$OPENSSL"
    "knm-$KONG_NGX_MODULE"
    "kbt-$KONG_BUILD_TOOLS"
  )

  GOJIRA_IMAGE=gojira:$(IFS="-" ; echo "${components[*]}")
}


function build {
  image_name

  BUILD_ARGS=(
    "--build-arg LUAROCKS=$LUAROCKS"
    "--build-arg OPENSSL=$OPENSSL"
    "--build-arg OPENRESTY=$OPENRESTY"
    "--build-arg KONG_NGX_MODULE=$KONG_NGX_MODULE"
    "--build-arg KONG_BUILD_TOOLS=$KONG_BUILD_TOOLS"
  )

  >&2 echo "Building $GOJIRA_IMAGE"
  >&2 echo ""
  >&2 echo "       Version info"
  >&2 echo "=========================="
  >&2 echo " * OpenSSL:     $OPENSSL  "
  >&2 echo " * OpenResty:   $OPENRESTY"
  >&2 echo " * LuaRocks:    $LUAROCKS "
  >&2 echo " * Kong BT:     $KONG_BUILD_TOOLS"
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


function p_compose {
  get_envs
  docker-compose -f <($COMPOSE_FILE) -p $PREFIX "$@"
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
  pushd $GOJIRA_KONG_PATH
    sha=$(git hash-object kong-*.rockspec)
  popd
  sha=$(echo $base_sha:$sha | sha1sum | awk '{printf $1}')
  GOJIRA_SNAPSHOT=gojira:snap-$GOJIRA_REPO-$sha
  GOJIRA_BASE_IMAGE=gojira:base-snap-$GOJIRA_REPO-$base_sha
}


function set_snapshot_image_name {
  if [[ ! -z $(query_image $GOJIRA_SNAPSHOT) ]]; then
    GOJIRA_IMAGE=$GOJIRA_SNAPSHOT
  elif [[ ! -z $(query_image $GOJIRA_BASE_IMAGE) ]]; then
    # Bring base image up to date man!
    GOJIRA_IMAGE=$GOJIRA_BASE_IMAGE
    warn "Your snapshot is not up to date, bringing up your latest compatible" \
         "base, but remember to run 'make dev'!"
  else
    return 1
  fi
  return 0
}


function setup {
  mkdir -p $GOJIRA_KONGS
  [ -d $GOJIRA_HOME ] || cp -r $DOCKER_PATH/home_template $GOJIRA_HOME
  # Ideally we figure out when we need to have a GOJIRA_KONG_PATH or not
  # so we can create it from here.
}

function snapshot {
  local c_id=$(p_compose ps -q kong)
  if [[ -n $GOJIRA_BASE_IMAGE ]]; then
    docker commit $c_id $GOJIRA_BASE_IMAGE || exit 1
  fi
  docker commit $c_id $GOJIRA_SNAPSHOT || exit 1
}

function run_command {
  local where=$1
  # Default node is 1
  local nodes=${2:-1}
  local args

  if [[ ! -z $_RAW_INPUT ]]; then
    args=$EXTRA_ARGS
  else
    # https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
    args=${_EXTRA_ARGS[@]@Q}
  fi

  if [[ -n $GOJIRA_RUN_CLUSTER ]]; then
    nodes=$(p_compose ps | awk '{ print $1 }' | grep "$where_'[0-9]*$'"| wc -l | bc)
    nodes=$(seq 1 $nodes)
  fi

  for i in $nodes; do
    if [[ -t 1 ]]; then
      p_compose exec --index $i $where sh -l -i -c "$args"
    else
      p_compose exec --index $i -T $where sh -l -c "$args"
    fi
  done
}


main() {
  parse_args "$@"
  setup

  case $ACTION in
  up)
    # kong path does not exist. This means we are upping a build that came
    # with no auto deps, most probably
    if [[ ! -d "$GOJIRA_KONG_PATH" ]]; then create_kong; fi

    local run_make_dev

    if [[ -z $GOJIRA_IMAGE ]] && [[ "$GOJIRA_USE_SNAPSHOT" == 1 ]]; then
      build
      if ! snapshot_image_name && [[ "$GOJIRA_MAGIC_DEV" == 1 ]]; then
        run_make_dev=1
      fi
      set_snapshot_image_name
    fi

    if [[ -z $GOJIRA_IMAGE ]]; then
      build || exit 1
    fi

    p_compose up -d $EXTRA_ARGS || exit 1

    if [[ $GOJIRA_MAGIC_DEV == 1 ]] && [[ -n $run_make_dev ]]; then
      p_compose exec kong $GOJIRA_SHELL -l -i -c "make dev"
      if [[ $? == 0 ]] && [[ "$GOJIRA_USE_SNAPSHOT" == 1 ]]; then
        snapshot
      fi
    fi
    ;;
  down)
    p_compose kill
    p_compose down -v
    ;;
  shell)
    p_compose exec --index $GOJIRA_CLUSTER_INDEX kong $GOJIRA_SHELL -l -i
    ;;
  build)
    build
    ;;
  cd)
    if [[ ! -d "$GOJIRA_KONG_PATH" ]]; then create_kong; fi
    echo $GOJIRA_KONG_PATH
    cd $GOJIRA_KONG_PATH 2> /dev/null
    ;;
  run@)
    # Pop first argument
    local where=${_EXTRA_ARGS[0]}
    _EXTRA_ARGS=("${_EXTRA_ARGS[@]:1}")
    EXTRA_ARGS="${_EXTRA_ARGS[@]}"

    run_command $where $GOJIRA_CLUSTER_INDEX
    ;;
  run)
    run_command kong $GOJIRA_CLUSTER_INDEX
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
    snapshot_image_name
    set_snapshot_image_name
    p_compose $EXTRA_ARGS
    ;;
  snapshot)
    snapshot_image_name $EXTRA_ARGS
    snapshot $EXTRA_ARGS
    >&2 echo "Created snapshot: $GOJIRA_SNAPSHOT"
    ;;
  snapshot\?)
    snapshot_image_name $EXTRA_ARGS
    query_image $GOJIRA_SNAPSHOT || err "$GOJIRA_SNAPSHOT not found"
    ;;
  snapshot\!)
    snapshot_image_name $EXTRA_ARGS
    docker rmi $GOJIRA_SNAPSHOT || exit 1
    if [[ -n $GOJIRA_BASE_IMAGE ]]; then
      docker rmi $GOJIRA_BASE_IMAGE || exit 1
    fi
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
  version)
    echo $GOJIRA $GOJIRA_VERSION ${GOJIRA_ROARS[-1]}
    ;;
  nuke)
    docker rm -fv $($0 ps -aq)
    docker network prune -f
    [ -n "$FORCE" ] && rm -fr $GOJIRA_KONGS/* ;
    echo; (booom | sed -e 's/^/          /'); echo
    ;;
  *)
    if hash gojira-$ACTION ; then
        . gojira-$ACTION
    else
        usage
        exit 1
    fi
    ;;
  esac
}

pushd() { builtin pushd $1 > /dev/null; }
popd() { builtin popd > /dev/null; }

main "$@"
