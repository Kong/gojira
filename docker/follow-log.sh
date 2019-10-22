#!/usr/bin/env sh

trap exit INT TERM
mkdir -p $KONG_PREFIX/logs
touch $KONG_PREFIX/logs/access.log $KONG_PREFIX/logs/error.log
tail -F $KONG_PREFIX/logs/access.log $KONG_PREFIX/logs/error.log &
wait
