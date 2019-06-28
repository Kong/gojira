#!/usr/bin/env bash

GOJIRA=$(basename $0)
GOJIRA_VERSION=0.2.3
GOJIRA_PATH=$(dirname $(realpath $0))
DOCKER_PATH=$GOJIRA_PATH/docker
DOCKER_FILE=$DOCKER_PATH/Dockerfile
COMPOSE_FILE=$DOCKER_PATH/docker-compose.yml.sh

# Defaults
GOJIRA_KONGS=${GOJIRA_KONGS:-~/.gojira-kongs}
GOJIRA_HOME=${GOJIRA_HOME:-$GOJIRA_KONGS/.gojira-home/}
GOJIRA_DATABASE=postgres
GOJIRA_REPO=kong
GOJIRA_TAG=master
GOJIRA_GIT_HTTPS=${GOJIRA_GIT_HTTPS:-0}
GOJIRA_USE_SNAPSHOT=${GOJIRA_USE_SNAPSHOT:-0}

EXTRA_ARGS=""
GOJIRA_VOLUMES=""
GOJIRA_PORTS=""

unset FORCE
unset PREFIX
unset GOJIRA_KONG_PATH
unset GOJIRA_LOC_PATH
unset GOJIRA_SNAPSHOT
unset GOJIRA_HOSTNAME

function warn() {
  >&2 \echo -en "\033[1;33m"
  >&2 echo "WARNING: $@"
  >&2 \echo -en "\033[0m"
}

function err {
  >&2 echo $@
  exit 1
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
      -v|--verbose)
        set -x
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -k|--kong)
        GOJIRA_KONG_PATH=$(realpath $2)
        GOJIRA_LOC_PATH=1
        shift
        ;;
      -t|--tag)
        GOJIRA_TAG=$2
        shift
        ;;
      -p|--prefix)
        PREFIX=$2
        shift
        ;;
      -pp|--port)
        GOJIRA_PORTS+=$2,
        shift
        ;;
      -n|--network)
        GOJIRA_NETWORK=$2
        shift
        ;;
      --volume)
        GOJIRA_VOLUMES+=$2,
        shift
        ;;
      --cassandra)
        GOJIRA_DATABASE=cassandra
        ;;
      --alone)
        GOJIRA_DATABASE=
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
        shift
        ;;
      -f|--force)
        FORCE=1
        ;;
      --git-https)
        GOJIRA_GIT_HTTPS=1
        ;;
      -)
        EXTRA_ARGS+="$(cat $2) "
        shift
        ;;
      --)
        shift
        EXTRA_ARGS+="$@ "
        break
        ;;
      *)
        EXTRA_ARGS+="$1 "
        ;;
    esac
    shift
  done

  eval set -- "$EXTRA_ARGS"

  validate_arguments

  if [ ! -z "$GOJIRA_KONG_PATH" ]; then
    GOJIRA_REPO=$(basename $GOJIRA_KONG_PATH)
    pushd $GOJIRA_KONG_PATH
      GOJIRA_TAG=$(git rev-parse --abbrev-ref HEAD)
    popd
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
  export DOCKER_CTX=$DOCKER_PATH
  export GOJIRA_HOSTNAME
  export GOJIRA_HOME
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
  ROARS=(
    "RAWR" "urhghh" "tasty vagrant" "..." "nomnomnom" "beer"
    "\e[1m\e[31ma \e[33mw \e[93me \e[32ms \e[34mo \e[96mm \e[35me \e[0m"
    "\e[38;5;206m❤ \e[0m" "ゴジラ" "Fast Track" "coming to a theater near you"
  )
  echo -e ${ROARS[$RANDOM % ${#ROARS[@]}]}
}


function roar {
cat << EOF
                 _,-}}-._
                /\   }  /\\
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
  --image               image to use for kong
  --volume              add a volume to kong container
  --cassandra           use cassandra
  --alone               do not spin up any db
  --host                specify hostname for kong container
  --git-https           use https to clone repos
  -v,  --verbose        echo every command that gets executed
  -h,  --help           display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on \$GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

  build         build a docker image with the specified VERSIONS

  run           run a command on a running container

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

  # Get dependencies from travis.yml unless suplied
  local travis_yaml=$GOJIRA_KONG_PATH/.travis.yml
  LUAROCKS=${LUAROCKS:-$(yaml_find $travis_yaml LUAROCKS)}
  OPENSSL=${OPENSSL:-$(yaml_find $travis_yaml OPENSSL)}
  OPENRESTY=${OPENRESTY:-$(yaml_find $travis_yaml OPENRESTY_BASE)}

  if [[ -z $LUAROCKS || -z $OPENSSL || -z $OPENRESTY ]]; then
    err "${GOJIRA}: Could not guess version dependencies in" \
        "$travis_yaml. Specify versions as LUAROCKS, OPENSSL and"\
        "OPENRESTY envs"
  fi

  GOJIRA_IMAGE=gojira:luarocks-$LUAROCKS-openresty-$OPENRESTY-openssl-$OPENSSL
}


function build {
  image_name

  # Always include patches by default. Only avoid them on unsupported openssl
  # versions
  local with_patches
  local openresty_patches
  if [[ $OPENSSL == 1.0.* ]]; then
    openresty_patches="--no-openresty-patches"
    with_patches="no"
  else
    openresty_patches=""
    # It's always master on openresty-build-tools
    with_patches="master"
  fi

  BUILD_ARGS=(
    "--build-arg LUAROCKS=$LUAROCKS"
    "--build-arg OPENSSL=$OPENSSL"
    "--build-arg OPENRESTY=$OPENRESTY"
    "--build-arg OPENRESTY_PATCHES=$openresty_patches"
  )

  >&2 echo "Building $GOJIRA_IMAGE"
  >&2 echo ""
  >&2 echo "       Version info"
  >&2 echo "=========================="
  >&2 echo " * OpenSSL:     $OPENSSL  "
  >&2 echo " * OpenResty:   $OPENRESTY"
  >&2 echo "    > patches   $with_patches"
  >&2 echo " * LuaRocks:    $LUAROCKS "
  >&2 echo "=========================="
  >&2 echo ""

  docker build -f $DOCKER_FILE -t $GOJIRA_IMAGE ${BUILD_ARGS[*]} $DOCKER_PATH
}


function yaml_find {
  echo $(cat $1 | grep $2 | head -n 1 | sed 's/.*=//')
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
  GOJIRA_SNAPSHOT=gojira:snap-$sha
}


function setup {
  mkdir -p $GOJIRA_KONGS
  [ -d $GOJIRA_HOME ] || cp -r $DOCKER_PATH/home_template $GOJIRA_HOME
  # Ideally we figure out when we need to have a GOJIRA_KONG_PATH or not
  # so we can create it from here.
}


main() {
  parse_args $@
  setup

  case $ACTION in
  up)
    # kong path does not exist. This means we are upping a build that came
    # with no auto deps, most probably
    if [[ ! -d "$GOJIRA_KONG_PATH" ]]; then create_kong; fi

    if [[ -z $GOJIRA_IMAGE ]] && [[ "$GOJIRA_USE_SNAPSHOT" == 1 ]]; then
      build
      snapshot_image_name
      if [[ ! -z $(query_image $GOJIRA_SNAPSHOT) ]]; then
        GOJIRA_IMAGE=$GOJIRA_SNAPSHOT
      fi
    fi

    if [[ -z $GOJIRA_IMAGE ]]; then
      build || exit 1
    fi
    p_compose up -d
    ;;
  down)
    p_compose kill
    p_compose down -v
    ;;
  shell)
    p_compose exec kong bash -l -i
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
    if [[ -t 1 ]]; then
      p_compose exec kong bash -l -i -c "$EXTRA_ARGS"
    else
      p_compose exec -T kong bash -l -c "$EXTRA_ARGS"
    fi
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
    p_compose $EXTRA_ARGS
    ;;
  snapshot)
    snapshot_image_name $EXTRA_ARGS
    local cmd='cat /proc/self/cgroup | head -1 | sed "s/.*docker\///"'
    local c_id=$(p_compose exec -T kong bash -c "$cmd" | tr -d '\r')
    docker commit $c_id $GOJIRA_SNAPSHOT || exit 1
    >&2 echo "Created snapshot: $GOJIRA_SNAPSHOT"
    ;;
  snapshot\?)
    snapshot_image_name $EXTRA_ARGS
    query_image $GOJIRA_SNAPSHOT || err "$GOJIRA_SNAPSHOT not found"
    ;;
  snapshot\!)
    snapshot_image_name $EXTRA_ARGS
    docker rmi $GOJIRA_SNAPSHOT || exit 1
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
    echo $GOJIRA $GOJIRA_VERSION
    ;;
  nuke)
    docker rm -fv $($0 ps -aq)
    docker network prune -f
    [ -n "$FORCE" ] && rm -fr $GOJIRA_KONGS/* ;
    echo; (booom | sed -e 's/^/          /'); echo
    ;;
  *)
    usage
    exit 1
    ;;
  esac
}

pushd() { builtin pushd $1 > /dev/null; }
popd() { builtin popd > /dev/null; }

main $*
