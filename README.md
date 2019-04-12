```
                            _,-}}-._          
                           /\   }  /\         
                          _|(O\_ _/O)        
                        _|/  (__''__)         
                      _|\/    WVVVVW     RAWR 
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
  -t, --tag     git tag to mount kong on (default: master)
  -p, --prefix  prefix to use for namespacing
  -k, --kong    PATH for a kong folder, will ignore tag
  --auto        try to read dependency versions from .travis file
  -h, --help    display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on $GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

  build         build a docker image with the specified VERSIONS

  run           run a command on a running container
                  *  gojira run -t tag make dev
                  *  gojira run -t tag bin/kong roar
                  *  gojira run -t tag bin/kong start

  shell         get a shell on a running container

```
