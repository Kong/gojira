#!/usr/bin/env bash

#!/bin/bash

function install_deck() {
  if [ ! -f /usr/local/bin/deck ]; then
    download_url=$(curl -s https://api.github.com/repos/kong/deck/releases/latest | jq -r ".assets[] | select(.name | test(\"linux_amd64.tar.gz\")) | .browser_download_url")
    curl -L "$download_url" -o /tmp/deck.tgz
    tar -xf /tmp/deck.tgz -C /tmp
    cp /tmp/deck /usr/local/bin/
  fi
}

install_deck
