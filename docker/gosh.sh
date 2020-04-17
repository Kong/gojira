#!/usr/bin/env sh

# Welcome to GoSH: gojira shell

if hash bash 2> /dev/null; then
  /usr/bin/env bash $@
elif hash ash 2> /dev/null; then
  /usr/bin/env ash $@
else
  /usr/bin/env sh $@
fi
