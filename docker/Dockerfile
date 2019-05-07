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
        libpcre3-dev \
        libyaml-dev

# LuaRocks - OpenSSL - OpenResty
ARG LUAROCKS
ARG OPENSSL
ARG OPENRESTY
ARG BUILD_TOOLS=master

ENV BUILD_PREFIX=/build
ENV BUILD_TOOLS_INSTALL=${BUILD_PREFIX}/openresty-build-tools

ENV OPENSSL_INSTALL=${BUILD_PREFIX}/openssl
ENV OPENRESTY_INSTALL=${BUILD_PREFIX}/openresty
ENV LUAROCKS_INSTALL=${BUILD_PREFIX}/luarocks

RUN mkdir -p ${BUILD_TOOLS_INSTALL}
RUN curl -sSL https://github.com/kong/openresty-build-tools/archive/${BUILD_TOOLS}.tar.gz \
                | tar -v -C ${BUILD_TOOLS_INSTALL} -xz --strip-components=1
RUN ${BUILD_TOOLS_INSTALL}/kong-ngx-build --prefix    ${BUILD_PREFIX} \
                                          --openresty ${OPENRESTY} \
                                          --openssl   ${OPENSSL} \
                                          --luarocks  ${LUAROCKS} \
                                          --no-openresty-patches

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
        iputils-ping

COPY bashrc /root/.bashrc
COPY follow-log.sh /bin/follow-kong-log

WORKDIR /kong
