#!/usr/bin/env bash

GOJIRA=$(basename $0)
GOJIRA_PATH=$(dirname $(realpath $0))
DOCKER_PATH=$GOJIRA_PATH/docker
DOCKER_FILE=$DOCKER_PATH/Dockerfile
COMPOSE_FILE=$DOCKER_PATH/docker-compose.yml.sh

# Defaults
GOJIRA_KONGS=${GOJIRA_KONGS:-~/.gojira-kongs}
GOJIRA_DATABASE=postgres
GOJIRA_REPO=kong
GOJIRA_TAG=master

EXTRA_ARGS=""
GOJIRA_VOLUMES=""
GOJIRA_PORTS=""

unset PREFIX
unset GOJIRA_KONG_PATH
unset GOJIRA_LOC_PATH
unset GOJIRA_RUN_FILE
unset GOJIRA_SNAPSHOT


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
        ;;
      -k|--kong)
        GOJIRA_KONG_PATH=$2
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
      -r|--repo)
        GOJIRA_REPO=$2
        shift
        ;;
      -f|--file)
        GOJIRA_RUN_FILE=$2
        shift
        ;;
      *)
        EXTRA_ARGS+="$1 "
        ;;
    esac
    shift
  done

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
  GOJIRA_SNAPSHOT=gojira:${EXTRA_ARGS:-$PREFIX}
}

function get_envs {
  # Maybe there's a better way. Plz tell
  printf "export GOJIRA_IMAGE=$GOJIRA_IMAGE "
  printf        "GOJIRA_KONG_PATH=$GOJIRA_KONG_PATH "
  printf        "GOJIRA_NETWORK=$GOJIRA_NETWORK "
  printf        "GOJIRA_PORTS=$GOJIRA_PORTS "
  printf        "GOJIRA_VOLUMES=$GOJIRA_VOLUMES "
  printf        "GOJIRA_DATABASE=$GOJIRA_DATABASE "
  printf        "DOCKER_CTX=$DOCKER_PATH "
  printf        "\n"
}


function create_kong {
  mkdir -p $GOJIRA_KONGS
  pushd $GOJIRA_KONGS
    git clone -b ${GOJIRA_TAG} https://github.com/kong/$GOJIRA_REPO.git $PREFIX || exit
  popd
}


function rawr {
  ROARS=(
    "RAWR" "urhghh" "tasty vagrant" "..." "nomnomnom" "beer"
    "\e[1m\e[31ma \e[33mw \e[93me \e[32ms \e[34mo \e[96mm \e[35me \e[0m"
    "\e[38;5;206m love ❤  \e[0m"
  )
  echo -e ${ROARS[$RANDOM % ${#ROARS[@]}]}
}


function usage {
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

                      Gojira (Godzilla)

Usage: $GOJIRA action [options...]

Options:
  -t,  --tag            git tag to mount kong on (default: master)
  -p,  --prefix         prefix to use for namespacing
  -k,  --kong           PATH for a kong folder, will ignore tag
  -n,  --network        use network with provided name
  -f,  --file           execute file instead of arg commands on gojira run
  -pp, --port           expose a port for a kong container
  --repo                use another kong repo
  --image               image to use for kong
  --volume              add a volume to kong container
  --cassandra           use cassandra
  --alone               do not spin up any db
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

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in \$GOJIRA_KONGS

  snapshot      make a snapshot of a running gojira

  compose       alias for docker-compose, try: gojira compose help

EOF
}


function build {
  if [[ ! -z $GOJIRA_IMAGE ]]; then
    return
  fi


  # No supplied dependency versions
  if [[ -z $LUAROCKS || -z $OPENSSL || -z $OPENRESTY ]]; then
    # No supplied local kong path and kong prefix does not exist
    if [[ -z "$KONG_LOC_PATH" && ! -d "$GOJIRA_KONGS/$PREFIX" ]]; then
      create_kong
    fi
  fi

  # Get dependencies from travis.yml unless suplied
  local travis_yaml=$GOJIRA_KONG_PATH/.travis.yml
  LUAROCKS=${LUAROCKS:-$(yaml_find $travis_yaml LUAROCKS)}
  OPENSSL=${OPENSSL:-$(yaml_find $travis_yaml OPENSSL)}
  OPENRESTY=${OPENRESTY:-$(yaml_find $travis_yaml OPENRESTY_BASE)}

  if [[ -z $LUAROCKS || -z $OPENSSL || -z $OPENRESTY ]]; then
    >&2 echo "${GOJIRA}: Could not guess version dependencies in" \
             "$travis_yaml. Specify versions as LUAROCKS, OPENSSL and"\
             "OPENRESTY envs"
    exit 1
  fi

  GOJIRA_IMAGE=gojira:luarocks-$LUAROCKS-openresty-$OPENRESTY-openssl-$OPENSSL

  BUILD_ARGS=(
    "--build-arg LUAROCKS=$LUAROCKS"
    "--build-arg OPENSSL=$OPENSSL"
    "--build-arg OPENRESTY=$OPENRESTY"
  )

  >&2 echo "Building $GOJIRA_IMAGE"
  >&2 echo ""
  >&2 echo "       Version info"
  >&2 echo "=========================="
  >&2 echo " * OpenSSL:     $OPENSSL  "
  >&2 echo " * OpenResty:   $OPENRESTY"
  >&2 echo " * LuaRocks:    $LUAROCKS "
  >&2 echo "=========================="
  >&2 echo ""

  docker build -f $DOCKER_FILE -t $GOJIRA_IMAGE ${BUILD_ARGS[*]} $DOCKER_PATH
}


function yaml_find {
  echo $(cat $1 | grep $2 | head -n 1 | sed 's/.*=//')
}


function p_compose {
  docker-compose -f <($(get_envs) ; $COMPOSE_FILE) -p $PREFIX "$@"
}


function compose {
  docker-compose -f <($(get_envs) ; $COMPOSE_FILE) "$@"
}


main() {
  parse_args $@

  case $ACTION in
  up)
    build || exit 1
    # kong path does not exist. This means we are upping a build that came
    # with no auto deps, most probably
    if [[ ! -d "$GOJIRA_KONG_PATH" ]]; then create_kong; fi
    p_compose up -d
    ;;
  down)
    p_compose kill
    p_compose down
    ;;
  shell)
    p_compose exec kong bash -l -i
    ;;
  build)
    build
    ;;
  cd)
    echo $GOJIRA_KONG_PATH
    cd $GOJIRA_KONG_PATH
    ;;
  -h|--help|help)
    usage
    ;;
  run)
    if [[ -z $GOJIRA_RUN_FILE ]]; then
      p_compose exec kong bash -l -i -c "$EXTRA_ARGS"
    else
      p_compose exec kong bash -l -i -c "$(cat $GOJIRA_RUN_FILE)"
    fi
    ;;
  images)
    docker images --filter=reference='gojira*' $EXTRA_ARGS
    ;;
  ps)
    PREFIXES=$(
      docker ps --filter "label=com.docker.compose.project" -q \
      | xargs docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' \
      | uniq
    )
    for pref in $PREFIXES; do
      compose -p $pref ps $EXTRA_ARGS
    done
    ;;
  ls)
    ls -1 $EXTRA_ARGS $GOJIRA_KONGS
    ;;
  compose)
    p_compose $EXTRA_ARGS
    ;;
  snapshot)
    local cmd='cat /proc/self/cgroup | head -1 | sed "s/.*docker\///"'
    local c_id=$(p_compose exec kong bash -l -i -c "$cmd" | tr -d '\r')
    docker commit $c_id $GOJIRA_SNAPSHOT || exit 1
    >&2 echo "Created snapshot: $GOJIRA_SNAPSHOT"
    ;;
  snapshot\?)
    local has_image=$(docker images "--filter=reference=$GOJIRA_SNAPSHOT" -q)
    if [[ -z $has_image ]]; then
      exit 1
    fi
    echo $GOJIRA_SNAPSHOT
    ;;
  snapshot\!)
    docker rmi $GOJIRA_SNAPSHOT || exit 1
    ;;
  *)
    usage
    ;;
  esac
}

main $*
