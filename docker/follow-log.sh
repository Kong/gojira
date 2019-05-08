#!/usr/bin/env bash

trap exit INT TERM
mkdir -p $KONG_PREFIX/logs
cd $KONG_PREFIX/logs
touch access.log error.log
tail -F access.log error.log &
wait
