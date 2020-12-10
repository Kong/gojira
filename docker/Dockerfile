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
ARG GO_VERSION
ARG KONG_GO_PLUGINSERVER

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

# Go and go-pluginserver
ENV GO_VERSION=${GO_VERSION}
ENV GOROOT=${BUILD_PREFIX}/go
ENV GOPATH=${BUILD_PREFIX}/gopath
ENV PATH=$GOPATH/bin:${GOROOT}/bin:$PATH
RUN mkdir -p ${GOROOT} ${GOPATH}

RUN curl -L https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
	tar -xf /tmp/go.tar.gz -C ${GOROOT} --strip-components=1 && \
    rm /tmp/go.tar.gz

ENV KONG_GO_PLUGINSERVER_INSTALL=${BUILD_PREFIX}/gps
ENV KONG_GO_PLUGINSERVER=${KONG_GO_PLUGINSERVER}

RUN go version && \
	mkdir ${KONG_GO_PLUGINSERVER_INSTALL} && \
    cd ${KONG_GO_PLUGINSERVER_INSTALL} && \
	go mod init go-pluginserver && \
	go get -d -v github.com/Kong/go-pluginserver@${KONG_GO_PLUGINSERVER} && \
	go install -ldflags="-s -w -X main.version=${KONG_GO_PLUGINSERVER}" ... && \
	cd && \
    rm -r ${KONG_GO_PLUGINSERVER_INSTALL} && \
	go-pluginserver --version

RUN cpanm --notest Test::Nginx
RUN cpanm --notest local::lib

COPY 42-kong-envs.sh /etc/profile.d/

WORKDIR /kong
