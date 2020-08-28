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
  -n,  --network        use network with provided name
  -r,  --repo           repo to clone kong from
  -pp, --port           expose a port for a kong container
  -v,  --volume         add a volume to kong container
  --image               image to use for kong
  --cassandra           use cassandra
  --alone               do not spin up any db
  --redis-cluster       run redis in cluster mode
  --host                specify hostname for kong container
  --git-https           use https to clone repos
  -V,  --verbose        echo every command that gets executed
  -h,  --help           display this help

Commands:
  up            start a kong. if no -k path is specified, it will download
                kong on $GOJIRA_KONGS folder and checkouts the -t tag.
                also fires up a postgres database .with it. for free.

  down          bring down the docker-compose thingie running in -t tag.
                remove it, nuke it from space. something went wrong, and you
                want a clear start or a less buggy tool to use.

  build         build a docker image with the specified VERSIONS

  run           run a command on a running kong container.
                Use with --cluster to run the command across all kong nodes.
                Use with --index 4 to run the command on node #4.

  run@[serv]    run a command on a specified service.
                example: 'gojira run@db psql -U kong'

  shell         get a shell on a running kong container.

  shell@[serv]  get a shell on a specified service.

  cd            cd into a kong prefix repo

  image         show current gojira image

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in $GOJIRA_KONGS

  lay           make gojira lay an egg

  snapshot      make a snapshot of a running gojira

  compose       alias for docker-compose, try: gojira compose help

  roar          make gojira go all gawo wowo

  logs          follow container logs

  nuke [-f]     remove all running gojiras. -f for removing all files

```

# gojira

gojira comes from far away to put an end to `vagrant up`, `vagrant destroy` and
`vagrant wait ten hours`.

Spin up as many kong instances as you want. On different commits at the same
time. With different openssl, openresty and luarocks versions. Run a shell
inside of the containers, make kong roar. Make kong fail, cd into the repo, fix
it. Make kong start again. Commit it. Push it, ship it!


## Installation

gojira depends on docker (18.09.02) and docker-compose (1.23.2). As usual, the
most recent, the better.

> Note you need `~/.local/bin` on your `$PATH`.

```
PATH=$PATH:~/.local/bin
git clone git@github.com:Kong/kong-gojira.git
mkdir -p ~/.local/bin
ln -s $(realpath kong-gojira/gojira.sh) ~/.local/bin/gojira
```

### Additional for OS X

```
brew install coreutils
```


## Usage

For the time being, we have a [guide].
Also, a [vagrant to gojira guide].

[guide]: doc/manual.md
[vagrant to gojira guide]: doc/vagrant.md

## Environment variables

Certain behaviours of gojira can be tamed by using the following environment
variables.

### GOJIRA_REPO

> default: `kong`

Default repository to clone from.

### GOJIRA_TAG

> default: `master`

Default tag to clone from `GOJIRA_REPO` when no `-t` has been provided


### GOJIRA_KONGS

> default: `~/.gojira/kongs`

Path where prefixes are stored


### GOJIRA_HOME

> default: `~/.gojira/home`

Path to the shared home between gojiras


### GOJIRA_IMAGE

Instead of building a development image, force this image to be used. [Docs]

[Docs]: doc/manual.md#using-kong-release-images-with-gojira

### GOJIRA_GIT_HTTPS

> default: `0` (off)

Use https instead of ssh for cloning `GOJIRA_REPO`


### GOJIRA_DETECT_LOCAL

> default: `1` (on)

Detects if the current path is a kong repository, providing an automatic `-k`
flag. [Docs]

[Docs]: doc/manual.md#detect-kong-in-path

### GOJIRA_PIN_LOCAL_TAG

> default: `1` (on)

When using a local path (-k or auto), it will always generate the same gojira
prefix based on the md5 of the path. [Docs]

[Docs]: doc/manual.md#detect-kong-in-path

### GOJIRA_USE_SNAPSHOT

> default: `1` (on)

Try to use an automatic snapshot when available. [Docs]

[Docs]: doc/manual.md#using-snapshots-to-store-the-state-of-a-running-container

### GOJIRA_MAGIC_DEV

> default: `0` (off)

Runs `make dev` on up when the environment needs it.

Together with `GOJIRA_USE_SNAPSHOT`, it will record a snapshot after so the
next up can re-use that snapshot. On luarocks change, it will bring up a
compatible base, and run 'make dev' again, which should be faster since it
will be incremental, but will not record a snapshot to reduce disk usage.

Read more about `GOJIRA_MAGIC_DEV` on the [manual] section.

[manual]: doc/manual.md#gojira-magic-dev-mode

### GOJIRA_KONG_PATH

Set this to a **full** kong path so gojira always references it no matter what
This efectively hardcodes all the gojira magic to always, always use this path,
without having to reference it by `-k`. ie

```bash
export GOJIRA_KONG_PATH=full/path/to/some/kong
```

