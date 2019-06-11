#!/usr/bin/env bash

# Add here any hack necessary to get a precise version of kong built.

BUILD_TOOLS_INSTALL=${BUILD_PREFIX}/openresty-build-tools
BUILD_TOOLS_CMD=${BUILD_TOOLS_INSTALL}/kong-ngx-build
BUILD_LOG=${BUILD_PREFIX}/build.log

function download_build_tools {
  mkdir -p ${BUILD_TOOLS_INSTALL}
  curl -sSL https://github.com/kong/openresty-build-tools/archive/${BUILD_TOOLS}.tar.gz \
            | tar -C ${BUILD_TOOLS_INSTALL} -xz --strip-components=1
}

function fn_exists {
  declare -f $1 > /dev/null
  return $?
}

function load_version_checks {
  # Load version comparison functions from build tool
  local err="Seems openresty-build-tools:${BUILD_TOOLS} does not contain \
             needed version checking functions"
  source ${BUILD_TOOLS_CMD}
  set +e
  fn_exists version_lte || (>&2 echo $err && exit 1)
  fn_exists version_gt  || (>&2 echo $err && exit 1)
}

function make_kong_ngx_module {
  make -C ${KONG_NGX_MODULE} LUA_LIB_DIR=${OPENRESTY_INSTALL}/lualib install
}

function init_timer {
  local sp="⣾⣽⣻⢿⡿⣟⣯⣷"
  local sc=0

  while true; do
    >&2 printf "\033[1K\r${sp:$sc % 24:3} $1 "
    ((sc+=3))
    sleep 0.5
  done
}

function build {
  local flags=(
    "--prefix    ${BUILD_PREFIX}"
    "--openresty ${OPENRESTY}"
    "--openssl   ${OPENSSL}"
    "--luarocks  ${LUAROCKS}"
  )
  local after=()

  if version_lte $OPENSSL 1.0; then
    flags+=("--no-openresty-patches")
  fi

  if version_gte $OPENSSL 1.1; then
    flags+=("--add-module $KONG_NGX_MODULE")
    after+=(make_kong_ngx_module)
  fi

  local cmd="${BUILD_TOOLS_CMD} ${flags[*]}"
  >&2 echo $cmd

  local timer_pid res
  init_timer "Building base dependencies" &
  timer_pid=$!
  disown

  $cmd &> ${BUILD_LOG}
  res=$?

  kill $timer_pid &> /dev/null
  >&2 printf "\n"

  if [[ ! "$res" == 0 ]]; then
    >&2 echo "Error building base dependencies:"
    >&2 tail -n 10 ${BUILD_LOG}
    exit 1
  fi

  >&2 tail -n 2 ${BUILD_LOG}

  for cb in "${after[@]}"; do $cb; done
}

download_build_tools
load_version_checks
build
