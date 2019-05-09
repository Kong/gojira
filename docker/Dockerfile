FROM ubuntu:xenial

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
        make \
        perl \
        unzip \
        zlib1g-dev \
        libssl-dev \
        git \
        m4 \
        libpcre3 \
        libpcre3-dev

# Extra tools
RUN apt-get update && \
    apt-get install -y  \
        jq \
        httpie \
        libyaml-dev

ARG LUAROCKS
ARG OPENSSL
ARG OPENRESTY

ENV DOWNLOAD_CACHE=/build/download-cache
ENV INSTALL_CACHE=/build/install-cache

ENV OPENSSL_INSTALL=${INSTALL_CACHE}/openssl-$OPENSSL
ENV OPENRESTY_INSTALL=${INSTALL_CACHE}/openresty-$OPENRESTY
ENV LUAROCKS_INSTALL=${INSTALL_CACHE}/luarocks-$LUAROCKS

ADD setup_env.sh .
RUN bash -x setup_env.sh

ENV OPENSSL_DIR=${OPENSSL_INSTALL}
ENV OPENSSL_LIBDIR=${OPENSSL_INSTALL}

ENV PATH=$PATH:${OPENRESTY_INSTALL}/nginx/sbin:${OPENRESTY_INSTALL}/bin:${LUAROCKS_INSTALL}/bin
ENV PATH=${OPENSSL_INSTALL}/bin:$PATH
ENV LD_LIBRARY_PATH=${OPENSSL_INSTALL}/lib:${LD_LIBRARY_PATH}

COPY bashrc /root/.bashrc
COPY follow-log.sh /bin/follow-kong-log

WORKDIR /kong
