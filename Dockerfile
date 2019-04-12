FROM kong:ubuntu-xenial


RUN apt-get update && \
    apt-get install -y libpcre3 libpcre3-dev
RUN apt-get install -y jq httpie libyaml-dev

ADD setup_env.sh .
ARG LUAROCKS=3.0.4
ARG OPENSSL=1.1.1a
ARG OPENRESTY=1.13.6.2
ENV DOWNLOAD_CACHE=/tmp/download-cache
ENV INSTALL_CACHE=/tmp/install-cache
ENV BUSTED_ARGS="-o gtest -v --exclude-tags=flaky,ipv6"
ENV TEST_FILE_PATH=$TRAVIS_BUILD_DIR/spec
ENV OPENSSL_INSTALL=${INSTALL_CACHE}/openssl-$OPENSSL
ENV OPENRESTY_INSTALL=${INSTALL_CACHE}/openresty-$OPENRESTY
ENV LUAROCKS_INSTALL=${INSTALL_CACHE}/luarocks-$LUAROCKS
ENV OPENSSL_DIR=${OPENSSL_INSTALL}
ENV PATH=$PATH:${OPENRESTY_INSTALL}/nginx/sbin:${OPENRESTY_INSTALL}/bin:${LUAROCKS_INSTALL}/bin
ENV LD_LIBRARY_PATH=${OPENSSL_INSTALL}/lib:${LD_LIBRARY_PATH}

RUN bash -x setup_env.sh
RUN echo "`luarocks path`" > $HOME/.bashrc

WORKDIR /kong
