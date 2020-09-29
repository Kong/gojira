#!/usr/bin/env bash

cat << EOF
version: '3.5'
services:
  # This will add / override compose confs on the whole compose file
  # explore it by running "gojira lay"

  # Override / add some parameters on the kong container
  ${GOJIRA_TARGET:-kong}:
    environment:
      - SAMPLE_PLUGIN=is best plugin

  # Let's say you want to add a new service to the setup
  # more_redis:
  #    image: redis
  # ...
EOF
