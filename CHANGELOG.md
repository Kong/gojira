# v0.5.0: the Bane of Anthropoids
* clone SHAs
* pg database with pg_stats enabled
* slightly better docs
* `--egg` flag exposing eggs
* `-e | --env` flag to specify ENV vars on `up` and `run` action
* `--network-mode` flag to set docker host mode (bridge, host, ...)
* go plugin server dependencies on the build
* and now... with less too!

# v0.4.0: An amazing project!
* small fixes around --alone flag
* home lives under ~/.gojira/home by default
* kongs live under ~/.gojira/kongs by default
* a LICENSE, CREDITS, and even COPYRIGHT!
* plugins system, with a sample plugin to use as a base
* tons of new ascii art
* roaring does not break anymore on < 10nth months

# v0.3.0: a Memento of the Past
* jq-free code
* gojira db as a shortcut to get a database shell (either psql or cqlsh)
* eggs are back on season
* redis-cluster mode fixes
* hybrid mode

# v0.2.9: The Houdini of the Seas
* run@service to run a command on a specified service
  ie: gojira run@db psql -U kong
* shell@service to get a shell on a specified service
  ie: gojira shell@db
* cluster flag to run a command across all nodes of a service
  ie: gojira up --scale kong=5
      gojira run --cluster kong version
* index flag to run a command on a specified node
  ie: gojira up --scale kong=5
      gojira run --index 3 kong version
* removes --shell flag
* introduces a shell bypass to get either bash, ash, or sh on kong
  containers.
* GOJIRA_MODE: kind of internal flag. It makes it transparent to use
  kong production images with 0 hassle.
    * 'image': disables fancy features, uses image name for prefixing.
      Makes extra sure that it does not download any kong. Useful for
      PS and CS support.
    * 'dev': the usual.
* GOJIRA_MAGIC_DEV: runs 'make dev' every time you up a container that
  has a snapshot layer of 0 (base image) or 1 (base snapshot). If it
  also has GOJIRA_USE_SNAPSHOT set to 1 (default), it will also record
  a snapshot if that happened on level 0.

# v0.2.8: King of Monsters
* remove pinned version of lua ngx module. Use .requirements
* remove openresty-branch
* fix md5/md5sum disparity
* add net cap to kong container
* base snapshots
* add --use-shell argument
* better defaults

# v0.2.7
* awesomeness

# v0.2.6
* uses bionic instead of xenial
* lua-kong-nginx-module no longer bundled
* support for building openresty with patches
* reads .requirements
* local (-k) kongs have deterministic prefix names (enabled by default)
* autodetect kong folders (disabled by default)

# v0.2.5
* redis mode (cluster)
* cmd args parsing
* mostly fixes about cmd args parsing :)

# v0.2.4
* improved roaring
* improved leaving
* improved tty allocation
* improved bash prompt
* improved handling of redis tests
* improved pdk tests!
* improved!

# v0.2.3
* shared home galore
* required env vars on profile instead of bashrc
* nuke fixes
* better docs
* servroot as anonymous volume
* lua-kong-nginx-module build
* better default snapshot names
* GOJIRA_USE_SNAPSHOT ups a default snapshot if found

# v0.2.2
* fix busted testing (add KONG_TEST_DNS_RESOLVER)
* add -- to stop argument parsing (gojira run -- make -k dev)
* add early exit on help
* fix LUA_PATH order
* add nuke command
* use openresty-build-tools (and patches support) to build base
  dependencies

# v0.2.1
* better `gojira ps` by using labels
* add redis
* increased log level on postgres
* add stream real ip flag for openresty
* uses a flag to specify an https git clone

# v0.2.0
* --host flag to specify kong container host
* fix a bug doing a gojira up of a local kong path

# v0.1.0
* Go go gojira!


                                _,-}}-._
                               /\   }  /\
                              _|(O\_ _/O)
                            _|/  (__''__)
                          _|\/    WVVVVW
                         \ _\     \MMMM/_
                       _|\_\     _ '---; \_
                  /\   \ _\/      \_   /   \
                 / (    _\/     \   \  |'VVV
                (  '-,._\_.(      'VVV /
                 \         /   _) /   _)
                  '....--''\__vvv)\__vvv)      ldb

                          Gojira (Godzilla)
