#!/bin/bash

set -e
eval `luarocks path`
exec "$@"
