# Manual

Gojira is a multi-purpose tool to ease development and testing of Kong by
using docker containers. Very similar to a vagrant environment, but completely
unlike it.

Whilst developing, it's very easy to jump between branches, different versions
and dependencies. With gojira, you can have as many instances running different
versions at the same time. The base dependencies are only built once, and
the state of a container [can be stored for later reuse](#using-snapshots-to-store-the-state-of-a-running-container).

It's very important to understand that it uses docker and docker-compose under
the hood. The best summary would be a docker-compose file with flags and super
powers. Read more about [gojira compose](#fallback-to-docker-compose) command.

Of course, nothing prevents running _just one_ kong instance, very similarly to
how vagrant is used. Read more about working with [local kong paths](#local).

## Getting started

First things first, let's verify that gojira is working:

```
$ gojira roar
                 _,-}}-._
                /\   }  /\
               _|(O\_ _/O)
             _|/  (__''__)
           _|\/    WVVVVW    you're breathtaking!
          \ _\     \MMMM/_
        _|\_\     _ '---; \_
   /\   \ _\/      \_   /   \
  / (    _\/     \   \  |'VVV
 (  '-,._\_.(      'VVV /
  \         /   _) /   _)
   '....--''\__vvv)\__vvv)      ldb
```

Let's run a `gojira up` and see what happens

```
$ gojira up
Cloning into 'kong-master'...
[...]
Building gojira:luarocks-3.2.1-openresty-1.15.8.2_master-openssl-1.1.1d

       Version info
==========================
 * OpenSSL:     1.1.1d
 * OpenResty:   1.15.8.2
   + patches:   master
 * LuaRocks:    3.2.1
==========================

Sending build context to Docker daemon  20.99kB
Step 1/26 : FROM ubuntu:bionic
 ---> 2ca708c1c9cc
[...]
Creating network "kong-master_gojira" with the default driver
Creating kong-master_db_1    ... done
Creating kong-master_redis_1 ... done
Creating kong-master_kong_1  ... done
```

It cloned `kong` master into `~/.gojira-kongs/kong-master`, built all the needed
dependencies, tagged it as `gojira:luarocks-3.2.1-openresty-1.15.8.2_master-openssl-1.1.1d`
and started a docker-compose prefix called `kong-master` together with a
database and redis.

Running gojiras can be checked by `gojira ps`. Let's try with a branch now.
When no `-t` is provided it defaults to `master`.

```
$ gojira up -t 1.2.0
Cloning into 'kong-1.2.0'...
[...]
Building gojira:luarocks-2.4.3-openresty-1.13.6.2_master-openssl-1.1.1b

       Version info
==========================
 * OpenSSL:     1.1.1b
 * OpenResty:   1.13.6.2
   + patches:   master
 * LuaRocks:    2.4.3
==========================
[...]
Creating network "kong-120_gojira" with the default driver
Creating kong-120_redis_1 ... done
Creating kong-120_db_1    ... done
Creating kong-120_kong_1  ... done
```

Notice the different dependencies between them. If we now `gojira ps`, the
two instances are running independently of each other. And we can work with
one or the other.

To access the directory where gojira downloaded the code, gojira can be
sourced together with the cd command:

```
$ source gojira cd
/some/path/to/.gojira-kongs/kong-master
$ . gojira cd -t 1.2.0
/some/path/to/.gojira-kongs/kong-1.2.0
```

It's all fun to have running containers, but it's even better to do something
with them! Let's run a make dev inside the running gojiras:

```
$ gojira run make dev
$ gojira run -t 1.2.0 make dev
```

By using the `-t 1.2.0` we are referencing to the running gojira on that
branch. With no `-t`, it defaults to the one on the `master` branch.

We can also get a shell into them

```
$ gojira shell -t 1.2.0
[kong-1.2.0:/kong]# exit
$ gojira shell
[kong-master:/kong]#
```

All gojira instances share a folder between them: `$HOME`. Try it:

```
$ gojira shell -t 1.2.0
[kong-1.2.0:/kong]# touch $HOME/foobar
[kong-1.2.0:/kong]# exit
$ gojira shell
[kong-master:/kong]# ls $HOME
foobar
[kong-master:/kong]#
```

By default, this folder is stored at `~/.gojira-kongs/.gojira-home`. It's a
very useful place to have rc files, utils and provides a customization point
for gojira.

The pattern of having prefixes stored under `~/.gojira-kongs` is very useful
for quick testing different versions and forgetting about where to store them.
But it might not be the most common case. That's what the `-k` flag is for:

```
$ gojira -k some/path/to/a/kong
Building gojira:luarocks-3.1.3-openresty-1.15.8.1_master-openssl-1.1.1c
[...]
Creating network "kong-0c4151a3c047b3f5592cce0ad4afaaa6_gojira" with the default driver
Creating kong-0c4151a3c047b3f5592cce0ad4afaaa6_db_1    ... done
Creating kong-0c4151a3c047b3f5592cce0ad4afaaa6_redis_1 ... done
Creating kong-0c4151a3c047b3f5592cce0ad4afaaa6_kong_1  ... done
```

There's now a container running under the fixed prefix `kong-0c4151a3c047b3f5592cce0ad4afaaa6`.
Any gojira command that references this path will access it.

All `gojira` commands run from within a kong repository will assume a `-k` flag
into it, making the following two commands equivalent:

```
# reference a path by -k
gojira up -k some/path/to/kong
# run it from within a kong folder
cd some/path/to/kong
gojira up
```

To disable this behavior, set `GOJIRA_DETECT_LOCAL=0`.

That's the main gist of it. The following are examples of different usage
patterns that are possible by using gojira.

## Usage patterns

### Start kong (master)

By default, gojira uses `master` as the default branch.

```
$ gojira up
Building gojira:luarocks-3.0.4-openresty-1.13.6.2-openssl-1.1.1a

       Version info
==========================
[...]
Creating network "kong-master_gojira" with the default driver
Creating kong-master_redis_1 ... done
Creating kong-master_db_1    ... done
Creating kong-master_kong_1  ... done
```

```
gojira run make dev
gojira run kong migrations bootstrap
gojira run kong start
gojira run kong roar
gojira run http :8001
```

We can access the path where kong is stored by

```
. gojira cd
```

### Using a branch

Specify a branch name using the `-t | --tag` flag

```
gojira up -t 0.34-1
```

From now on, this gojira is referenced by this tag. Starting kong now will be:

```
gojira run -t 0.34-1 make dev
gojira run -t 0.34-1 kong migrations up
gojira run -t 0.34-1 kong start
gojira run -t 0.34-1 kong roar
gojira run -t 0.34-1 http :8001
```

Note how you can also get a shell on it to do the same:

```
$ gojira shell -t 0.34-1
root@a02194e2ab87:/kong#
root@a02194e2ab87:/kong# make dev
root@a02194e2ab87:/kong# kong migrations up
...
```

Again, we can access the path where this kong prefix is stored by

```
. gojira cd -t 0.34-1
```


### Start a local kong

By using th `-k | --kong` flag, you can point to local kong folder.

```
$ gojira up -k path/to/some/kong
$ gojira run -k path/to/some/kong some commands
$ gojira shell -k path/to/some/kong
$ gojira down -k path/to/some/kong
```

Gojira will automatically detect when it runs within a kong repository. The
previous would become. Disable this feature by setting `GOJIRA_DETECT_LOCAL=0`.

```
$ cd path/to/some/kong
$ gojira up
$ gojira run some commands
$ gojira shell
$ gojira down
```

### Kill Gojiras

- `gojira nuke` will kill all gojira running containers.
- `gojira nuke -f` will kill all gojira running containers AND remove
the repos in `$GOJIRA_KONGS`.

The `nuke` command proxies extra commands to the first `docker ps`,
that allows extra filtering like `gojira nuke --filter name=sealy`.


### Using two gojiras with the same version

gojira has the notion of prefixes. With the `-p | --prefix` flag you can avoid
overlapping on the namespaces. Each prefix is completely separate of the other

```
gojira up -p foo
gojira up -p bar
gojira run -p foo kong roar
gojira run -p bar kong roar
. gojira cd -p foo
. gojira cd -p bar
```

### Using two gojiras with the same database

It's useful for testing migrations. The following will up two kongs on
different versions using the same database and do a migration:

```bash
# Start a node on 0.36-1
gojira up -t 0.36-1 --network some-network
gojira run -t 0.36-1 kong migrations bootstrap
gojira run -t 0.36-1 kong start

# Start a node on 1.3.0.2 on the same network without db
gojira up -t 1.3.0.2 --network some-network --alone
gojira run -t 1.3.0.2 kong migrations up
gojira run -t 1.3.0.2 kong migrations finish
gojira run -t 1.3.0.2 kong start
```

### Using kong release images with gojira

```bash
# or set it with --image argument
export GOJIRA_IMAGE=kong:1.5.0-alpine
gojira up
gojira shell
kong roar
kong migrations bootstrap
kong start
```

### Using snapshots to store the state of a running container

It's possible to create snapshots of running containers. Snapshots are useful
to keep a copy of the system environment running on a kong prefix. It's boring
to run `make dev` over and over again.

```
$ gojira up
$ gojira run make dev
$ gojira run apt install iputils-ping
$ gojira snapshot
...
Created snapshot: gojira:7c52c791796bd9de81ecc3aa4e5df78e0b80fa57
```

From now on, we can use this snapshot instead of any other image

```
$ gojira up --image gojira:7c52c791796bd9de81ecc3aa4e5df78e0b80fa57
$ gojira run kong roar
$ gojira run ping db
```

By default, the snapshot name is a sha composed of the base image sha and the
sha of the kong rockspec file. This gives a valid default as a compromise on
what kind of snapshot we can consider valid between runs. If either the base
dependencies or the rockspec changes, the snapshot becomes invalid. Of course,
shas are not very readable, so you can manually instead specify a snapshot
name.

```
$ gojira snapshot much-better-name
...
Created snapshot: much-better-name
$ gojira up --image much-better-name
```

It's also possible to ask gojira if a snapshot exists

```
$ gojira snapshot?
gojira:7c52c791796bd9de81ecc3aa4e5df78e0b80fa57
$ gojira snapshot? much-better-name
much-better-name
$ gojira snapshot? non-existent
X $
```

By default, gojira will load a snapshot if found. If you want to disable
this behavior, set `GOJIRA_USE_SNAPSHOT=0`

Notice how you can install more tools and overwrite the snapshot at any time.

```
gojira up
gojira run make dev
gojira snapshot
gojira down

gojira up
gojira run kong roar
gojira apt install postgresql-client
gojira snapshot
gojira down

gojira up
gojira run kong roar
gojira run psql -U kong -h db
```

#### Snapshot levels

unnamed snapshots are created on two levels:
 - base snapshot: depends only on the Dockerfile and hard dependencies
   (luarocks, openssl, openresty).
 - snapshot: depends on the base snapshot + kong rockspec file

By having a base snapshot in hand, it's possible to bring up an environment
that is more or less compatible with the desired one, and it's just missing
an incremental `luarocks make` on the rockspec. When `GOJIRA_USE_SNAPSHOT` is
enabled and no snapshot is found, it will bring up the base snapshot if
available.

Base snapshots also ease the installation of tooling on the images, since
they will always be available on the base snapshot even when the level 2
snapshot changed.

Snapshots can be deleted by

```
$ gojira snapshot!
Untagged: gojira:7c52c791796bd9de81ecc3aa4e5df78e0b80fa57
Deleted: sha256:adf1489719318319e99a3ae1bf88ea8649d610d4546eab15be69882427e9cdc7
Deleted: sha256:3bceff26f6b1b4ac07bf097af1947591ce03ed4948c711a940fb21d97d695fdf
$ gojira snapshot! much-better-name
Untagged: much-better-name:latest
Deleted: sha256:4a65afc276faae30bcf9c7e2f412f8282ad16fdeb4cfb47c62b28a7d1ec4d889
Deleted: sha256:bbad8e16eab22ac4538f282b4a5ed63cd0f91f03b76ae1327f8318e9f3504522
```

Base snapshots can be deleted by

```
$ gojira snapshot!!
```

### Gojira magic dev mode

It might seem a bit pointless to run `make dev` every time you up a container.
Gojira environments should be something we freely bring up, down and nuke, but
it's troublesome to keep track of the state of the environment.

By setting `GOJIRA_MAGIC_DEV=1`, gojira will run `make dev` every time
after `gojira up`.

Combined with `GOJIRA_USE_SNAPSHOT=1` it will save a base snapshot after the
first `make dev`. After this, you can forget about typing
`make dev` ever again. When something changes on the rockspec, it will bring
up the base snapshot and the `make dev` will take much less time since it will
be incremental.

** this is an experimental feature ** report any issues on #gojira

### fallback to docker-compose

- `gojira compose config  # useful for debugging`

Note that `gojira compose run X` and `gojira run X` mean different
things as docker-compose run will spawn a new container and gojira
will effectively exec into kong service. More or less:

`gojira compose exec kong top` == `gojira run top`

`gojira compose exec db psql`  == `gojira run@db psql`

### plugin development

Set `KONG_PLUGINS` and mount your plugin path to `/kong-plugin/`

```
KONG_PLUGINS=rate-limiting-advanced gojira up --volume /absolute/path/:/kong-plugin/
gojira run bin/busted /kong-plugin/specs/
gojira shell
  kong migrations bootstrap
  kong start
  http :8001/ | jq '.["plugins"]["available_on_server"]["rate-limiting-advanced"]  # true!
```

### Access database console

```
gojira run@db psql -U kong      # Postgres
gojira run@db cqlsh             # Cassandra
```

### Run an sql file in the db

`/root/` is also shared by the database containers, so you keep your
cassandra history and psql history.

```
gojira run@db psql -- -U kong -d kong_tests -f'/root/foo.sql'
```

### Remove all gojira images (including snapshots)

```
docker rmi $(gojira images -q)
```


### Run both cassandra and postgres tests on the same run

The solution for this is to spin up a cassandra container separately
on a joined network. Note that for full test coverage it's recommended
to run specs normally setting `KONG_TEST_DATABASE` to the specific
target.

```
docker run --name gojira_cassandra --network foobar -d cassandra:3.9
KONG_TEST_CASSANDRA_CONTACT_POINTS=gojira_cassandra KONG_CASSANDRA_CONTACT_POINTS=gojira_cassandra gojira up --network foobar
gojira shell
$ unset KONG_TEST_DATABASE
$ bin/busted -o gtest some/tests
```

### Run a kong cluster

A kong cluster is basically multiple kong versions using the same database.
Remember to use snapshots to not waste time. The following example starts a
kong cluster of 5 nodes.

```bash
# First let's make sure we have a snapshot for the node we want to bring up
# skip this step if you know that you have an snapshot
gojira up --alone
gojira run make dev
gojira snapshot
gojira down

# Now, start gojira with 5 kong nodes
gojira up --scale kong=5

# Run migrations on the first node
gojira run kong migrations bootstrap
# Start kong in all nodes
gojira run --cluster kong start
```

Note that the following do more or less the same:

```bash
gojira up --scale kong=5
# and
gojira up
gojira compose scale kong=5
```

> For the time being, we have no mode for load balancing kong requests across
  the cluster.

#### Run a command on a particular node (ie: 3)

```bash
gojira run --index 3 foobar
```

#### Run a shell on a particular node (ie: 3)

```bash
gojira shell --index 3
```


#### Scale any other service

```bash
gojira up --scale db=9000 --scale kong=3000

# Alternatively
gojira up
gojira compose scale db=9000
gojira compose scale kong=3000
```
### Extending gojira functionality

One size fits all, except when it does not. Gojira is a development tool, and
every developer has a different workflow. The basic setup tries to provide a
good scaffold to work with kong, but some workflows are more involved than
others. Extend gojira functionality by:

#### Using configuration environment variables

Global settings might be useful to tune gojira. See: [README]

[README]: README.md#environment-variables

#### Gojira home

All gojira target containers, regardless of the network or settings share a
common home folder under `/root`. By default, it is mounted at the host
filesystem at `~/.gojira/home`, though this path can be changed by setting
`GOJIRA_HOME` to any other path.

Through this shared home it's possible to customize the shell on gojira by
modifying `.bashrc`: editor settings, available utilities, scripts, the same
way any other system shell is configured.

#### Using eggs

A gojira egg is any yaml file or executable producting a yaml output compatible
with docker compose. Use eggs to add or override anything on the resulting
docker-compose yml that gojira produces.

##### Examine generated yaml

```bash
$ gojira lay
...
networks:
  gojira: {}
services:
  db:
    environment:
      POSTGRES_DBS: kong,kong_tests
      POSTGRES_HOST_AUTH_METHOD: trust
      POSTGRES_USER: kong
    healthcheck:
      interval: 5s
...
$ gojira lay -pp 8000
...
    ports:
    - published: 8000
      target: 8000
...
```

##### Example: bind ports on any service

```yaml
# all-exposed.yml
version: '3.5'
services:
  kong:
    ports:
      - 8001:8001
      - 8000:8000
  redis:
    ports:
      - 6379:6379
  db:
    ports:
      - 5432:5432
```

```bash
$ gojira lay --egg all-exposed.yml
... yml output including exposed ports ...
$ gojira up --egg all-exposed.yml
```

##### Example: include a new service

Let's say it's interesting to us to add a prometheus node within the gojira
network. We could do this manually by running docker commands on a particular
network, but it's very easy to write that as a reusable gojira egg that will
be composed together with the base generated yaml.

```yaml
# with-prometheus.yml
version: '3.5'
services:
  prometheus:
    image: prom/prometheus
    ports:
    - 9090:9090
    labels:
      com.konghq.gojira: "True"
    networks:
    - gojira
```

```bash
$ gojira up --egg with-prometheus.yml
```

#### Commands

It's possible to add a new gojira command by making available to the shell
path an executable prefixed by `gojira-`. For example, `gojira-db` available
on the path would be executed by calling `gojira db`. See: [gojira-db]

[gojira-db]: /extra/gojira-db

#### Modes

Using the same principle as a command, it's possible to summarize a special
gojira behavior. See: [gojira-hybrid] mode.

[gojira-hybrid]: /extra/gojira-hybrid

#### Plugins

Gojira can be completely customized and extended by using plugins. A plugin is
any bash code that will be sourced during gojira initialization. It must be
available on the shell path prefixed by `gojira-`, and configured through
`GOJIRA_PLUGINS` environment variable, separated by commas.

For the [sample plugin], that would be

```bash
$ PATH=$PATH:~/path/to/gojira/plugins
$ GOJIRA_PLUGINS="sample"
$ gojira sample help
```

[sample plugin]: /plugins/gojira-sample
