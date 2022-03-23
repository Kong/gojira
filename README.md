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
```

# gojira

Gojira is a multi-purpose tool to ease the development and testing of Kong by
using Docker containers. Very similar to a Vagrant environment, but completely
unlike it.

It comes from far away to put an end to `vagrant up`, `vagrant destroy` and
`vagrant wait ten hours`.

Spin up as many Kong instances as you want. On different commits at the same
time. With different OpenSSL, OpenResty and LuaRocks versions. Run a shell
inside of the containers, make Kong roar. Make Kong fail, cd into the repo, fix
it. Make Kong start again. Commit it. Push it, ship it!

## Synopsis

```
Usage: gojira action [options...]

Options:
  -t,  --tag            git tag to mount kong on (default: master)
  -p,  --prefix         prefix to use for namespacing
  -k,  --kong           PATH for a kong folder, will ignore tag
  -n,  --network        use network with provided name
  -r,  --repo           repo to clone kong from
  -pp, --port           expose a port for a kong container
  -v,  --volume         add a volume to kong container
  -e,  --env KEY=VAL    add environment variable binding to kong container
  --image               image to use for kong
  --cassandra           use cassandra
  --alone               do not spin up any db
  --redis-cluster       run redis in cluster mode
  --host                specify hostname for kong container
  --git-https           use https to clone repos
  --egg                 add a compose egg to make things extra yummy
  --network-mode        set docker network mode
  --yml FILE            kong yml file
  --apt-mirror DOMAIN   use customized Ubuntu apt mirror (such as --apt-mirror apt-mirror.example.com)
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

  run@s[:i]     run a command on a specified service (node i)
                example: 'gojira run@db psql -U kong'

  shell         get a shell on a running kong container.

  shell@s[:i]   get a shell on a specified service s (node i)
                example: 'gojira shell@db'

  port          get allocated random port for kong
  port@s[:i]    or for a specified service s (node i)
                example: 'gojira port 8000'
                         'gojira port@kong:3 8000'
                         'gojira port@redis 6379'

  watch         watch a file or a pattern for changes and run an action on the
                target container
                example: 'gojira watch kong.yml "kong reload"'
                         'gojira watch "* **/**/*"  "kong reload"'

  cd            cd into a kong prefix repo

  image         show current gojira image

  images        list gojira images

  ps            list running prefixes

  ls            list stored prefixes in $GOJIRA_KONGS

  lay           make gojira lay an egg

  snapshot[?!]  make a snapshot of a running gojira

  compose       alias for docker-compose, try: gojira compose help

  roar          make gojira go all gawo wowo

  logs          follow container logs

  nuke [-f]     remove all running gojiras. -f for removing all files

  version       make a guess
```


## Installation

gojira depends on `bash`, `git`, `docker` and `docker-compose`. Make sure your
docker setup is compatible with [compose file v3.5](https://docs.docker.com/compose/compose-file/compose-file-v3/).

```bash
$ git clone https://github.com/Kong/gojira.git
$ mkdir -p ~/.local/bin
$ ln -s $(realpath gojira/gojira.sh) ~/.local/bin/gojira
```

> Note you need `~/.local/bin` on your `$PATH`. Add them to `~/.profile`,
`.zshrc`, `~/.bashrc` or `~/.bash_profile` depending on which shell you use.

```bash
export PATH=~/.local/bin:$PATH
```

### Additional OSX dependencies

#### GNU core utilities

```
$ brew install coreutils
```

#### Bash > 3

OSX ships with old Bash versions. It's recommended to upgrade bash to an
up-to-date version of Bash.

```bash
$ brew install bash
```

> Homebrew will symlink bash into `/usr/local/bin`.

```bash
$ /bin/bash --version
GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin19)
Copyright (C) 2007 Free Software Foundation, Inc.
$ /usr/local/bin/bash --version
GNU bash, version 5.1.4(1)-release (x86_64-apple-darwin19.6.0)
Copyright (C) 2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
```
Make sure your `$PATH` gives higher precendence to the upgraded bash.

```bash
$ where bash
/usr/local/bin/bash
/bin/bash
$ bash --version
GNU bash, version 5.1.4(1)-release (x86_64-apple-darwin19.6.0)
```

If that's not the case, there are many ways of making sure
`/usr/local/bin/bash` takes precedence over `/bin/bash`. If unsure, the
following should work without unintended side effects, assuming your `$PATH`
contains `~/.local/bin` on the leftmost (highest) position.

```bash
$ export PATH=~/.local/bin:$PATH
$ ln -s $(realpath /usr/local/bin/bash) ~/.local/bin/bash
$ bash --version
GNU bash, version 5.1.4(1)-release (x86_64-apple-darwin19.6.0)
```

## Usage

* [Getting started](docs/manual.md#getting-started)
* [Usage patterns](docs/manual.md#usage-patterns)
* [From vagrant to gojira](docs/vagrant.md)

## Configuration

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

Instead of building a development image, force this image to be used.
[Docs](docs/manual.md#using-kong-release-images-with-gojira)

### GOJIRA_GIT_HTTPS

> default: `0` (off)

Use https instead of ssh for cloning `GOJIRA_REPO`


### GOJIRA_DETECT_LOCAL

> default: `1` (on)

Detects if the current path is a kong repository, providing an automatic `-k`
flag.
[Docs](docs/manual.md#start-a-local-kong)

### GOJIRA_PIN_LOCAL_TAG

> default: `1` (on)

When using a local path (-k or auto), it will always generate the same gojira
prefix based on the md5 of the path.
[Docs](docs/manual.md#start-a-local-kong)

### GOJIRA_USE_SNAPSHOT

> default: `1` (on)

Try to use an automatic snapshot when available.
[Docs](docs/manual.md#using-snapshots-to-store-the-state-of-a-running-container)

### GOJIRA_MAGIC_DEV

> default: `0` (off)

Runs `make dev` on up when the environment needs it.

Together with `GOJIRA_USE_SNAPSHOT`, it will record a snapshot after so the
next up can re-use that snapshot. On luarocks change, it will bring up a
compatible base, and run 'make dev' again, which should be faster since it
will be incremental, but will not record a snapshot to reduce disk usage.
[Docs](docs/manual.md#gojira-magic-dev-mode)

### GOJIRA_KONG_PATH

Set this to a **full** kong path so gojira always references it no matter what
This effectively hardcodes all the gojira magic to always, always use this path,
without having to reference it by `-k`. ie

```bash
export GOJIRA_KONG_PATH=full/path/to/some/kong
```

### GOJIRA_NETWORK_MODE

> default: (empty)

Use `network_mode` to spin up containers. When no network mode is set, it will
use docker's default (bridge), see https://docs.docker.com/network/#network-drivers
for available modes.
[Docs](docs/manual.md#bind-ports-on-the-host)

## Credits

* gojira artwork by ascii artist [ldb](http://asciiartist.com).
