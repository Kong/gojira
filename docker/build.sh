#!/usr/bin/env bash

source ${BUILD_PREFIX}/silent/silent-run.sh

# Add here any hack necessary to get a precise version of kong built.

BUILD_TOOLS_INSTALL=${BUILD_PREFIX}/kong-build-tools
BUILD_TOOLS_DIR=${BUILD_TOOLS_INSTALL}/openresty-build-tools
BUILD_TOOLS_CMD=${BUILD_TOOLS_DIR}/kong-ngx-build
BUILD_LOG=${BUILD_PREFIX}/build.log

KONG_NGX_MODULE_INSTALL=${BUILD_PREFIX}/lua-kong-nginx-module

# Set this to download lua-kong-nginx-module manually
# some versions of openresty-build-tools won't work with versions
# so it will restort to this
NGX_MODULE_MANUAL=0

function download_build_tools {
  mkdir -p ${BUILD_TOOLS_INSTALL}
  curl -sSL https://github.com/Kong/kong-build-tools/archive/${KONG_BUILD_TOOLS}.tar.gz \
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

  # Hack for 0.36 ...
  if version_lt $OPENRESTY 1.15; then
    KONG_NGX_MODULE=0.0.4
  fi

  if version_gte $OPENSSL 1.1; then
    if [[ $NGX_MODULE_MANUAL == 1 ]]; then
      # We are building lua-kong-nginx-module manually and including it with
      # Add lua-kong-nginx-module and after-party
      download_lua-kong-nginx-module
      flags+=("--no-kong-nginx-module")
      flags+=("--add-module $KONG_NGX_MODULE_INSTALL")
      # Stream part not compatible with open resty < 1.5
      # I know we should be pinning these versions but this is a quickfix
      if [[ -d $KONG_NGX_MODULE_INSTALL/stream ]] && version_gte $OPENRESTY 1.15; then
        flags+=("--add-module $KONG_NGX_MODULE_INSTALL/stream")
      fi
      after+=(make_kong_ngx_module)
    else
      flags+=("--kong-nginx-module $KONG_NGX_MODULE")
    fi
  fi

  local cmd="${BUILD_TOOLS_CMD} ${flags[*]}"
  >&2 echo $cmd

  start_silent_run "Building base dependencies"
    $cmd
  stop_silent_run

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
