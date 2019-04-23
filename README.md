```
                            _,-}}-._ 
                           /\   }  /\ 
                          _|(O\_ _/O) 
                        _|/  (__''__) 
                      _|\/    WVVVVW    tasty vagrant!
                     \ _\     \MMMM/_ 
                   _|\_\     _ '---; \_ 
              /\   \ _\/      \_   /   \ 
             / (    _\/     \   \  |'VVV 
            (  '-,._\_.(      'VVV / 
             \         /   _) /   _) 
              '....--''\__vvv)\__vvv)      ldb

                      Gojira (Godzilla)

Usage: gojira action [options...]

Options:
  -t,  --tag            git tag to mount kong on (default: master)
  -p,  --prefix         prefix to use for namespacing
  -k,  --kong           PATH for a kong folder, will ignore tag
  -kp, --kong-plugin    PATH for a kong-plugin folder
  --no-auto             do not try to read dependency versions from .travis.yml
  -v,  --verbose        echo every command that gets executed
  -h,  --help           display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on $GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

  stop          stop the docker-compose thingie running in -t tag.

  build         build a docker image with the specified VERSIONS

  run           run a command on a running container
                  *  gojira run -t tag make dev
                  *  gojira run -t tag bin/kong roar
                  *  gojira run -t tag bin/kong start

  shell         get a shell on a running container

  cd            cd into a kong prefix repo

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in $GOJIRA_KONGS

```

# gojira

gojira comes from far away to put an end to `vagrant up`, `vagrant destroy` and
`vagrant wait ten hours`.

Spin up as many kong instances as you want. On different commits at the same
time. With different openssl, openresty and luarocks versions. Run a shell
inside of the containers, make kong roar. Make kong fail, cd into the repo, fix
it. Make kong start again. Commit it. Push it, ship it!

In all seriousness, use this tool only for development, for anything serious
use [kong-build-tools].

[kong-build-tools]: https://github.com/Kong/kong-build-tools


## Installation

```
git clone git@github.com:Kong/kong-gojira.git
ln -s kong-gojira/gojira.sh ~/.local/bin/gojira
```

### Additional for OS X

```
brew install coreutils
```

