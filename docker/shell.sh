#!/usr/bin/env sh

if hash zsh 2> /dev/null; then
  /usr/bin/env zsh $@
elif hash bash 2> /dev/null; then
  /usr/bin/env bash $@
elif hash ash 2> /dev/null; then
  /usr/bin/env ash $@
else
  /usr/bin/env sh $@
fi
