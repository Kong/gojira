#!/usr/bin/env bash

# Add here any hack necessary to get a precise version of kong built.

BUILD_TOOLS_INSTALL=${BUILD_PREFIX}/openresty-build-tools
BUILD_TOOLS_CMD=${BUILD_TOOLS_INSTALL}/kong-ngx-build
BUILD_LOG=${BUILD_PREFIX}/build.log

KONG_NGX_MODULE_INSTALL=${BUILD_PREFIX}/lua-kong-nginx-module

function download_build_tools {
  mkdir -p ${BUILD_TOOLS_INSTALL}
  curl -sSL https://github.com/kong/openresty-build-tools/archive/${BUILD_TOOLS}.tar.gz \
            | tar -C ${BUILD_TOOLS_INSTALL} -xz --strip-components=1
}

function download_lua-kong-nginx-module {
  mkdir -p ${KONG_NGX_MODULE_INSTALL}
  curl -sSL https://github.com/kong/lua-kong-nginx-module/archive/${KONG_NGX_MODULE}.tar.gz \
            | tar -C ${KONG_NGX_MODULE_INSTALL} -xz --strip-components=1
}

function make_kong_ngx_module {
  make -C ${KONG_NGX_MODULE_INSTALL} LUA_LIB_DIR=${OPENRESTY_INSTALL}/lualib install
}

function init_timer {
  local sp="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

  local sc=0

  while true; do
    >&2 printf "\033[1K\r${sp:$sc % 24:3} $1 "
    ((sc+=3))
    sleep 0.1
  done
}

function build {
  local flags=(
    "--prefix    ${BUILD_PREFIX}"
    "--openresty ${OPENRESTY}"
    "--openssl   ${OPENSSL}"
    "--luarocks  ${LUAROCKS}"
    # We are building lua-kong-nginx-module manually and including it with
    # --add-module on compatible versions.
    "--no-kong-nginx-module"
  )
  local after=()

  if version_lte $OPENSSL 1.0; then
    flags+=("--no-openresty-patches")
  fi

  if version_gte $OPENSSL 1.1; then
    # Set openresty patches branch
    flags+=("--openresty-patches ${OPENRESTY_PATCHES:-master}")

    # Add lua-kong-nginx-module and after-party
    download_lua-kong-nginx-module
    flags+=("--add-module $KONG_NGX_MODULE_INSTALL")
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

parse_version() {
  [[ -z $1 ]] || [[ -z $2 ]] && >&2 echo "parse_version() requires two arguments" && exit 1

  local ver
  local subj=$1

  if [[ $subj =~ ^[^0-9]*(.*) ]]; then
    subj=${BASH_REMATCH[1]}

    local re='^(-rc[0-9]+$)?[.]?([0-9]+|[a-zA-Z]+)?(.*)$'

    while [[ $subj =~ $re ]]; do
      if [[ ${BASH_REMATCH[1]} != "" ]]; then
        ver="$ver.${BASH_REMATCH[1]}"
      fi

      if [[ ${BASH_REMATCH[2]} != "" ]]; then
        ver="$ver.${BASH_REMATCH[2]}"
      fi

      subj="${BASH_REMATCH[3]}"
      if [[ $subj == "" ]]; then
        break
      fi
    done

    ver="${ver:1}"

    IFS='.' read -r -a $2 <<< "$ver"
  fi
}

version_eq() {
  local version_a version_b

  parse_version $1 version_a
  parse_version $2 version_b

  # Note that we are indexing on the b components, ie: 1.11.100 == 1.11
  for index in "${!version_b[@]}"; do
    [[ "${version_a[index]}" != "${version_b[index]}" ]] && return 1
  done

  return 0
}

version_lt() {
  local version_a version_b

  parse_version $1 version_a
  parse_version $2 version_b

  for index in "${!version_a[@]}"; do
    if [[ ${version_a[index]} =~ ^[0-9]+$ ]]; then
      [[ "${version_a[index]}" -lt "${version_b[index]}" ]] && return 0
      [[ "${version_a[index]}" -gt "${version_b[index]}" ]] && return 1

    else
      [[ "${version_a[index]}" < "${version_b[index]}" ]] && return 0
      [[ "${version_a[index]}" > "${version_b[index]}" ]] && return 1
    fi
  done

  return 1
}

version_gt() {
  (version_eq $1 $2 || version_lt $1 $2) && return 1
  return 0
}

version_lte() {
  (version_lt $1 $2 || version_eq $1 $2) && return 0
  return 1
}

version_gte() {
  (version_gt $1 $2 || version_eq $1 $2) && return 0
  return 1
}

download_build_tools
build
