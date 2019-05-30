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

### store an image with the state of the current kong service container

- `gojira up -t master`
- `gojira run apt-get install iputils-ping -t master`
- `gojira snapshot -t master`
- `gojira up -t branch --image $snapshot_hash_or_id`
- `gojira run ping db`

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
gojira run bin/busted ../kong-plugin/specs/
gojira shell
  bin/kong migrations bootstrap
  bin/kong start
  http :8001/ | jq '.["plugins"]["available_on_server"]["rate-limiting-advanced"]  # true!
```
