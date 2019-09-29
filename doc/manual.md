# Manual

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

By turning on `GOJIRA_DETECT_LOCAL=1`, gojira will automatically detect when
it runs within a kong repository. The previous would become

```
$ export GOJIRA_DETECT_LOCAL=1
$ cd path/to/some/kong
$ gojira up
$ gojira run some commands
$ gojira shell
$ gojira down
```

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

### link 2 gojiras to the same db

| term1                                            | term2                                                                                                                       |
|--------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `gojira up -t 0.34-1 -n network1`                | `gojira up -t master -n network1 --alone`                                                                                   |
| `gojira run make dev -t 0.34-1 -n network1`      | `gojira run make dev -t master -n network1 --alone`                                                                             |
|                                                  | `gojira run bin/kong migrations bootstrap -t master -n network1`                                                            |
| `gojira run bin/kong start -t 0.34-1`            | `gojira run bin/kong start -t master`                                                                                       |
|                                                  | `gojira shell -t master`                                                                                                    |
|                                                  | `curl -i -X POST   --url http://localhost:8001/services/   --data 'name=example-service'   --data 'url=http://mockbin.org'` |
| `gojira run curl http://localhost:8001/services` |                                                                                                                             |


### use a different starting image

- `gojira up -t 0.34-1 --image bintray.....`

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

Thus, theoretically you can run the following and always get a container using
the image you snapshotted, without having to run `make dev` again.
```
$ gojira up --image $(gojira snapshot?)
$ gojira run kong roar
```

We hear you - This is neat! I do not want to type `make dev` again. Make this
the default - and we got you covered. This feature is nifty, but comes with
some compromises that might be non obvious, therefore it comes disabled by
default. Even if enabled, it will not do anything if an `--image` is provided.

All you need to do, is `export GOJIRA_USE_SNAPSHOT=1`

The following will always try to use an snapshot if it is available. Notice
how you can install more tools and overwrite the snapshot at any time.

```
export GOJIRA_USE_SNAPSHOT=1

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

### fallback to docker-compose

- `gojira compose config  # useful for debugging`

Note that `gojira compose run X` and `gojira run X` mean different
things as docker-compose run will spawn a new container and gojira
will effectively exec into kong service. More or less:
`gojira compose exec kong top` == `gojira run top`

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
gojira compose exec db psql -U kong    #Postgres
gojira compose exec db cqlsh           #Cassandra

```

### Remove all gojira images (including snapshots)

```
docker rmi $(gojira images -q)
```


### Run both cassandra and postgres tests on the same run

The solution for this is to spin up a cassandra container separately on a
joined network. Note that for full test coverage it's recommended to
run specs normally setting `KONG_TEST_DATABASE` to the specific target.

```
docker run --name gojira_cassandra --network foobar -d cassandra:3.9
KONG_TEST_CASSANDRA_CONTACT_POINTS=gojira_cassandra KONG_CASSANDRA_CONTACT_POINTS=gojira_cassandra gojira up --network foobar
gojira shell
$ unset KONG_TEST_DATABASE
$ bin/busted -o gtest some/tests
```

