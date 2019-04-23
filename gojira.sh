#!/usr/bin/env bash

GOJIRA=$(basename $0)
GOJIRA_PATH=$(dirname $(realpath $0))
DOCKER_FILE=$GOJIRA_PATH/Dockerfile
COMPOSE_FILE=$GOJIRA_PATH/docker-compose.yml

KONGS=${GOJIRA_KONGS:-~/.gojira-kongs}
LUAROCKS=${LUAROCKS:-3.0.4}
OPENSSL=${OPENSSL:-1.1.1a}
OPENRESTY=${OPENRESTY:-1.13.6.2}
KONG_PLUGINS=${KONG_PLUGINS:-bundled}

EXTRA=""
AUTO_DEPS=1

unset PREFIX
unset KONG_TAG
unset KONG_PATH
unset KONG_LOC_PATH
unset KONG_PLUGIN_PATH


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
        KONG_PATH=$2
        KONG_LOC_PATH=1
        shift
        ;;
      -kp|--kong-plugin)
        KONG_PLUGIN_PATH=$2
        shift
        ;;
      -t|--tag)
        KONG_TAG=$2
        shift
        ;;
      -p|--prefix)
        PREFIX=$2
        shift
        ;;
      --no-auto)
        AUTO_DEPS=0
        ;;
      *)
        EXTRA="$EXTRA $1"
        ;;
    esac
    shift
  done

  if [ -z "$KONG_PATH" ]; then
    KONG_TAG=${KONG_TAG:-master}
    if [ -n "$PREFIX" ]; then
      PREFIX=$PREFIX-$KONG_TAG
    else
      PREFIX=$KONG_TAG
    fi
    KONG_PATH=$KONGS/$PREFIX
  else
    get_branch
    if [ -n "$PREFIX" ]; then
      PREFIX=$PREFIX-$BRANCH_NAME
    else
      PREFIX=$BRANCH_NAME
    fi
  fi

}


function create_kong {
  mkdir -p $KONGS
  pushd $KONGS
    git clone -b ${KONG_TAG} git@github.com:Kong/kong.git $PREFIX || exit
  popd
}


function get_branch {
  pushd $KONG_PATH
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
  popd
}

function rawr {
  ROARS=("RAWR" "urhghh" "tasty vagrant" "..." "nomnomnom")
  echo ${ROARS[$RANDOM % ${#ROARS[@]}]}
}


function usage {
cat << EOF

                            _,-}}-._ 
                           /\   }  /\ 
                          _|(O\\_ _/O) 
                        _|/  (__''__) 
                      _|\/    WVVVVW    $(rawr)!
                     \ _\     \MMMM/_ 
                   _|\_\     _ '---; \_ 
              /\   \ _\/      \_   /   \ 
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
  -kp, --kong-plugin    PATH for a kong-plugin folder
  --no-auto             do not try to read dependency versions from .travis.yml
  -v,  --verbose        echo every command that gets executed
  -h,  --help           display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on \$GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

  stop          stop the docker-compose thingie running in -t tag.

  build         build a docker image with the specified VERSIONS

  run           run a command on a running container
                  *  gojira run -t tag make dev
                  *  gojira run -t tag bin/kong roar
                  *  gojira run -t tag bin/kong start

  shell         get a shell on a running container

  cd            cd into a kong prefix repo

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in \$GOJIRA_KONGS

EOF
}


function build {
  if [ $AUTO_DEPS -eq 1 ]; then
    if [ -z "$KONG_LOC_PATH" ]; then create_kong; fi

    TRAVIS_YAML=$KONG_PATH/.travis.yml
    LUAROCKS=$(yaml_find $TRAVIS_YAML LUAROCKS)
    OPENSSL=$(yaml_find $TRAVIS_YAML OPENSSL)
    OPENRESTY=$(yaml_find $TRAVIS_YAML OPENRESTY_BASE)

    if [[ -z $LUAROCKS || -z $OPENSSL || -z $OPENRESTY ]]; then
      >&2 echo "${GOJIRA}: Could not guess version dependencies in" \
               "$TRAVIS_YAML. try using --no-auto"

     exit 1
    fi
  fi

  IMAGE_NAME=gojira:luarocks-$LUAROCKS-openresty-$OPENRESTY-openssl-$OPENSSL
  KONG_IMAGE=$IMAGE_NAME

  # Surely, there's abetter way
  COMPOSE_ENVS="export KONG_IMAGE=$KONG_IMAGE \
                       KONG_PATH=$KONG_PATH \
                       KONG_PLUGIN_PATH=$KONG_PLUGIN_PATH \
                       KONG_PLUGINS=$KONG_PLUGINS"

  BUILD_ARGS=(
    "--build-arg LUAROCKS=$LUAROCKS"
    "--build-arg OPENSSL=$OPENSSL"
    "--build-arg OPENRESTY=$OPENRESTY"
  )
  >&2 echo "Building $IMAGE_NAME"
  >&2 echo ""
  >&2 echo "       Version info"
  >&2 echo "=========================="
  >&2 echo " * OpenSSL:     $OPENSSL  "
  >&2 echo " * OpenResty:   $OPENRESTY"
  >&2 echo " * LuaRocks:    $LUAROCKS "
  >&2 echo "=========================="
  >&2 echo ""

  docker build -f $DOCKER_FILE -t $IMAGE_NAME ${BUILD_ARGS[*]} $GOJIRA_PATH
}


function yaml_find {
  echo $(cat $1 | grep $2 | head -n 1 | sed 's/.*=//')
}


parse_args $@

case $ACTION in
up)
  if [[ ! -d "$KONG_PATH" ]]; then
    create_kong
  fi
  build
  ${COMPOSE_ENVS} ; docker-compose -f $COMPOSE_FILE -p $PREFIX up -d
  ;;
down)
  docker-compose -f $COMPOSE_FILE -p $PREFIX kill
  docker-compose -f $COMPOSE_FILE -p $PREFIX down
  ;;
stop)
  docker-compose -f $COMPOSE_FILE -p $PREFIX stop
  ;;
shell)
  docker-compose -f $COMPOSE_FILE -p $PREFIX exec kong bash -l -i
  ;;
build)
  build
  ;;
cd)
  echo $KONG_PATH
  cd $KONG_PATH
  ;;
-h|--help|help)
  usage
  ;;
run)
  ${COMPOSE_ENVS} ; docker-compose -f $COMPOSE_FILE -p $PREFIX exec kong bash -l -i -c "$EXTRA"
  ;;
images)
  docker images --filter=reference='gojira*' $EXTRA
  ;;
ps)
  docker ps --filter "label=com.docker.compose.project" -q \
      | xargs docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' \
      | uniq \
      | xargs -I pref docker-compose -f $COMPOSE_FILE -p pref ps $EXTRA 2> /dev/null
  ;;
ls)
  ls -1 $EXTRA $KONGS
  ;;
*)
  usage
  ;;
esac
