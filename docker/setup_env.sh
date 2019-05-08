#!/usr/bin/env bash
set -e

# Number of processors or JOBS env
NPROC=${JOBS:-$(nproc)}

# Blatantly stolen from kong-ci
# Add here as many hacks as needed to get certain versions installed

#---------
# Download
#---------
OPENSSL_DOWNLOAD=$DOWNLOAD_CACHE/openssl-$OPENSSL
OPENRESTY_DOWNLOAD=$DOWNLOAD_CACHE/openresty-$OPENRESTY
LUAROCKS_DOWNLOAD=$DOWNLOAD_CACHE/luarocks-$LUAROCKS

mkdir -p $OPENSSL_DOWNLOAD $OPENRESTY_DOWNLOAD $LUAROCKS_DOWNLOAD

if [ ! "$(ls -A $OPENSSL_DOWNLOAD)" ]; then
  pushd $DOWNLOAD_CACHE
    curl -s -S -L http://www.openssl.org/source/openssl-$OPENSSL.tar.gz | tar xz
  popd
fi

if [ ! "$(ls -A $OPENRESTY_DOWNLOAD)" ]; then
  pushd $DOWNLOAD_CACHE
    curl -s -S -L https://openresty.org/download/openresty-$OPENRESTY.tar.gz | tar xz
  popd
fi

if [ ! "$(ls -A $LUAROCKS_DOWNLOAD)" ]; then
  pushd $DOWNLOAD_CACHE
    curl -s -S -L https://github.com/luarocks/luarocks/archive/v$LUAROCKS.tar.gz | tar xz
  popd
fi

#--------
# Install
#--------
OPENSSL_INSTALL=$INSTALL_CACHE/openssl-$OPENSSL
OPENRESTY_INSTALL=$INSTALL_CACHE/openresty-$OPENRESTY
LUAROCKS_INSTALL=$INSTALL_CACHE/luarocks-$LUAROCKS

mkdir -p $OPENSSL_INSTALL $OPENRESTY_INSTALL $LUAROCKS_INSTALL

if [ ! "$(ls -A $OPENSSL_INSTALL)" ]; then
  pushd $OPENSSL_DOWNLOAD
    ./config shared --prefix=$OPENSSL_INSTALL &> build.log || (cat build.log && exit 1)
    make &> build.log || (cat build.log && exit 1)
    make install_sw &> build.log || (cat build.log && exit 1)
  popd
fi

if [ ! "$(ls -A $OPENRESTY_INSTALL)" ]; then
  OPENRESTY_OPTS=(
    "--prefix=$OPENRESTY_INSTALL"
    "--with-cc-opt='-I$OPENSSL_INSTALL/include'"
    "--with-ld-opt='-L$OPENSSL_INSTALL/lib -Wl,-rpath,$OPENSSL_INSTALL/lib'"
    "--with-pcre-jit"
    "--with-http_ssl_module"
    "--with-http_realip_module"
    "--with-http_stub_status_module"
    "--with-http_v2_module"
    "--with-stream_ssl_preread_module"
  )

  pushd $OPENRESTY_DOWNLOAD
    eval ./configure ${OPENRESTY_OPTS[*]} &> build.log || (cat build.log && exit 1)
    make -j$NPROC &> build.log || (cat build.log && exit 1)
    make install &> build.log || (cat build.log && exit 1)
  popd
fi

if [ ! "$(ls -A $LUAROCKS_INSTALL)" ]; then
  pushd $LUAROCKS_DOWNLOAD
    ./configure \
      --prefix=$LUAROCKS_INSTALL \
      --lua-suffix=jit \
      --with-lua=$OPENRESTY_INSTALL/luajit \
      --with-lua-include=$OPENRESTY_INSTALL/luajit/include/luajit-2.1 \
      &> build.log || (cat build.log && exit 1)
    make build -j$NPROC &> build.log || (cat build.log && exit 1)
    make install &> build.log || (cat build.log && exit 1)
  popd
fi

set +e
