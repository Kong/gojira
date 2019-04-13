#!/usr/bin/env bash

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

function parse_args {
  ACTION=$1
  shift

  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -h|--help)
        usage
        ;;
      -k|--kong)
        KONG_PATH=$2
        KONG_LOC_PATH=1
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
    git clone git@github.com:Kong/kong.git $PREFIX
    pushd $PREFIX
      git checkout ${KONG_TAG}
    popd
  popd
}


function get_branch {
  pushd $KONG_PATH
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
  popd
}

function rawr {
  ROARS=("RAWR" "urhghh" "tasty vagrant" "...")
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

Usage: $0 action [options...]

Options:
  -t, --tag     git tag to mount kong on (default: master)
  -p, --prefix  prefix to use for namespacing
  -k, --kong    PATH for a kong folder, will ignore tag
  --no-auto     do not try to read dependency versions from .travis file
  -h, --help    display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on \$GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

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
    # XXX: This is terrible
    if [ -z "$KONG_LOC_PATH" ]; then create_kong; fi
    LUAROCKS=$(yaml_find $KONG_PATH/.travis.yml LUAROCKS)
    if [ $? -ne 0 ]; then exit 1; fi
    OPENSSL=$(yaml_find $KONG_PATH/.travis.yml OPENSSL)
    if [ $? -ne 0 ]; then exit 1; fi
    OPENRESTY=$(yaml_find $KONG_PATH/.travis.yml OPENRESTY_BASE)
    if [ $? -ne 0 ]; then exit 1; fi
  fi

  IMAGE_NAME=gojira:luarocks-$LUAROCKS-openresty-$OPENRESTY-openssl-$OPENSSL
  KONG_IMAGE=$IMAGE_NAME

  # Surely, there's abetter way
  COMPOSE_ENVS="export KONG_IMAGE=$KONG_IMAGE \
                       KONG_PATH=$KONG_PATH \
                       KONG_PLUGINS=$KONG_PLUGINS"

  BUILD_ARGS="--build-arg LUAROCKS=$LUAROCKS \
              --build-arg OPENSSL=$OPENSSL \
              --build-arg OPENRESTY=$OPENRESTY"
  >&2 echo "Building $IMAGE_NAME"
  docker build -f $DOCKER_FILE -t $IMAGE_NAME $BUILD_ARGS $GOJIRA_PATH
}


function yaml_find {
  # Do you miss the days of PHP interop interpolation? I do sometimes
  # I was so excited trying to know if I could, that I did not ponder if I
  # should
  CMD=`cat <<EOF
import yaml
import sys

travis = yaml.load(open('$1'))
global_envs = {
  k: v for k, v in map(lambda e: e.split('='), travis['env']['global'])
}
sys.stdout.write(global_envs["$2"])
EOF
  `
  YAML_ENV=$(python3 -c "$CMD" 2>/dev/null)
  if [ $? -ne 0 ]; then
    exit 1
  fi
  echo $YAML_ENV
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
shell)
  docker-compose -f $COMPOSE_FILE -p $PREFIX exec kong bash
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
  ${COMPOSE_ENVS} ; docker-compose -f $COMPOSE_FILE -p $PREFIX exec kong bash -i -c "$EXTRA"
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
