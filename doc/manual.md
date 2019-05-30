# Manual

## Usage patterns

### Work on a branch

- `gojira up -t 0.34-1`.
- `gojira run make dev -t 0.34-1`
- `gojira run bin/kong migrations bootstrap -t 0.34-1`
- `gojira run bin/kong roar -t 0.34-1`
- `gojira shell -t 0.34-1`
- `curl http://localhost:8001`
- `. gojira cd -t 0.34-1`



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

```
KONG_PLUGINS=rate-limiting-advanced gojira up --volume /absolute/path/:/kong-plugin/ --volume /kong/servroot
gojira run bin/busted ../kong-plugin/specs/
```
