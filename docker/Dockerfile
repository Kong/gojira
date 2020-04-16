FROM ubuntu:bionic

# Build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        gettext-base \
        libgd-dev \
        libgeoip-dev \
        libncurses5-dev \
        libperl-dev \
        libreadline-dev \
        libxslt1-dev \
        libpasswdqc-dev \
        make \
        perl \
        unzip \
        zlib1g-dev \
        libssl-dev \
        git \
        m4 \
        libpcre3 \
        libpcre3-dev \
        libyaml-dev

# LuaRocks - OpenSSL - OpenResty
ARG LUAROCKS
ARG OPENSSL
ARG OPENRESTY
ARG KONG_NGX_MODULE
ARG KONG_BUILD_TOOLS

ENV BUILD_PREFIX=/build
ENV OPENSSL_INSTALL=${BUILD_PREFIX}/openssl
ENV OPENRESTY_INSTALL=${BUILD_PREFIX}/openresty
ENV LUAROCKS_INSTALL=${BUILD_PREFIX}/luarocks

RUN mkdir -p ${BUILD_PREFIX}
COPY build.sh ${BUILD_PREFIX}
COPY silent ${BUILD_PREFIX}/silent
RUN ${BUILD_PREFIX}/build.sh

ENV OPENSSL_DIR=${OPENSSL_INSTALL}
ENV OPENSSL_LIBDIR=${OPENSSL_INSTALL}

ENV PATH=$PATH:${OPENRESTY_INSTALL}/nginx/sbin:${OPENRESTY_INSTALL}/bin:${LUAROCKS_INSTALL}/bin
ENV PATH=${OPENSSL_INSTALL}/bin:$PATH
ENV LD_LIBRARY_PATH=${OPENSSL_INSTALL}/lib:${LD_LIBRARY_PATH}

# Extra tools
RUN apt-get update && \
    apt-get install -y  \
        jq \
        httpie \
        iputils-ping \
        cpanminus \
        iproute2

RUN cpanm --notest Test::Nginx
RUN cpanm --notest local::lib

COPY 42-kong-envs.sh /etc/profile.d/

WORKDIR /kong
