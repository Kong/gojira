# vagrant to gojira, a survival guide

![gojira](https://media.giphy.com/media/u0YUspFyoyqnm/giphy.gif)

### Welcome vagrant expats! Gojira loves you

Even if the two tools are conceptually different and the tongue in cheek jokes
about vagrant being slow and gojira awesome, they serve a very similar purpose.
If you look deep into them (and that's specially true for docker on os x), they
are the same thing. What gives gojira superpowers is the ability to run as many
environments as you want at the same time, effortlessly.

One of the fundamental differences is that gojira tries very hard at
differentiating environments, so each branch is going to be a different
instance of gojira. It does so to make sure we can run and work with different
branches at the same time, making it trivial to jump between them.

But first things first, and for the sake of developer time, let's get a similar
environment as we had on our vagrant setup. It's very important to note that
the following works, but it's not the only way of using gojira.

We have:

1. A folder with kong

We want:

2. Kong running
3. Postgres
4. Cassandra
5. To run tests
6. To run requests against kong

### Kong running

Before starting, make sure that `GOJIRA_DETECT_LOCAL` and `GOJIRA_PIN_LOCAL_TAG`
are both set to `1`. The first one makes it so gojira detects if you are
inside a `kong` repo, and will automatically reference it. The second
one makes it so gojira references that kong path always with the same name.

NOTE: If you have set `$KONG_PATH` for Vagrant, be sure to unset it before
running gojira. gojira assumes that `$KONG_PATH` indicates where to find KONG
_in the container_, not on the host.

We are also going to bind ports 8000 and 8001 to our host, so we can use them
as we did on our vagrant setup.

Note all these comands are run within a kong repo. To run them from outside
a kong folder, you still need to provide `-k path/to/kong` on any command.

```
$ cd path/to/kong
$ gojira up -pp 8000:8000 -pp 8001:8001
Building gojira:luarocks-3.0.4-openresty-1.13.6.2-openssl-1.1.1a

       Version info
==========================
 * OpenSSL:     1.1.1a
 * OpenResty:   1.13.6.2
 ...
```

Let's install the dev dependencies, and start kong. You can communicate with
the container by using the `gojira run` command or getting a shell by executing
`gojira shell`

```
$ gojira run make dev
...
$ gojira shell
root@a382e76b130a:/kong#
root@a382e76b130a:/kong# kong migrations bootstrap
...
root@a382e76b130a:/kong# kong start
...
root@a382e76b130a:/kong# exit
$ http :8001
```

### Postgres

Now we have something very similar to what the previous vagrant environment
provided. We have only binded the 8000 and 8001 ports, though, so if we want
to access postgres or cassandra, we need to execute it directly on the postgres
container, or install the clients on our kong running instance.

```
# Directly use the one in the postgres container
$ gojira run@db -- psql -U kong
psql (9.5.17)
Type "help" for help.

kong=#
```

```
# Install it into the kong container
$ gojira run apt install postgresql-client
$ gojira run -- psql -U kong -h db
psql (9.5.17)
Type "help" for help.

kong=#
```

### Cassandra

This is where things might get different. We do not want the same container
to also use cassandra. We want another environment that will use cassandra.
Thist time, let's up gojira with a prefix, `-p cassandra`.

```
$ cd path/to/kong
$ gojira up -p cassandra --cassandra -pp 8000:9000 -pp 8001:9001
$ gojira run -p cassandra make dev
$ gojira run -p cassandra kong migrations bootstrap
$ gojira run -p cassandra kong start
$ gojira shell -p cassandra
root@f648a8c047fe:/kong#
root@f648a8c047fe:/kong# apt install python3-pip
root@f648a8c047fe:/kong# pip install cqlsh
...
root@f648a8c047fe:/kong# cqlsh db
Connected to Test Cluster at 127.0.0.1:9042.
[cqlsh 5.0.1 | Cassandra 3.9 | CQL spec 3.4.2 | Native protocol v4]
...
```

gojira is just managing docker containers, so if we wanted, we could directly
use cqlsh inside the cassandra container too

```
$ gojira ps
CONTAINER ID        IMAGE                                                     COMMAND                  CREATED             STATUS                            PORTS                                         NAMES
1e2b7650423f        gojira:luarocks-3.0.4-openresty-1.13.6.2-openssl-1.1.1a   "follow-kong-log"        8 seconds ago       Up 7 seconds                                                                    cassandra-kong-master_kong_1
b57592c3cc1f        cassandra:3.9                                             "/docker-entrypoint.…"   9 seconds ago       Up 8 seconds (health: starting)   7000-7001/tcp, 7199/tcp, 9042/tcp, 9160/tcp   cassandra-kong-master_db_1
863b73fc9b0e        redis:5.0.4-alpine                                        "docker-entrypoint.s…"   9 seconds ago       Up 8 seconds (healthy)            6379/tcp                                      cassandra-kong-master_redis_1
940f54e5893f        gojira:luarocks-3.0.4-openresty-1.13.6.2-openssl-1.1.1a   "follow-kong-log"        2 minutes ago       Up 2 minutes                      0.0.0.0:8000-8001->8000-8001/tcp              kong-master_kong_1
5680f9d4d95b        postgres:9.5                                              "docker-entrypoint.s…"   2 minutes ago       Up 2 minutes (healthy)            5432/tcp                                      kong-master_db_1
66d459363ede        redis:5.0.4-alpine                                        "docker-entrypoint.s…"   2 minutes ago       Up 2 minutes (healthy)            6379/tcp                                      kong-master_redis_1

$ gojira run@db -p cassandra cqlsh
Connected to Test Cluster at 127.0.0.1:9042.
[cqlsh 5.0.1 | Cassandra 3.9 | CQL spec 3.4.2 | Native protocol v4]
...
$ docker exec -it b57592c3cc1f cqlsh
Connected to Test Cluster at 127.0.0.1:9042.
[cqlsh 5.0.1 | Cassandra 3.9 | CQL spec 3.4.2 | Native protocol v4]
...
```

### Running tests

Same as before

```
# From outside
$ gojira run bin/busted -o gtest -v spec/...
...
# Or from inside
$ gojira shell
root@f648a8c047fe:/kong#
root@f648a8c047fe:/kong# bin/busted -o gtest -v ...
...
```

### Requests against kong

Since we binded ports 8000-8001 and 9000-9001 to our host, we can make requests
from inside and outside the containers. Note, though, that binding ports is not
mandatory and we can get do by running httpie inside the containers.

```
$ gojira run -p cassadra http :8001
$ http :9001
$ gojira run http :8001
$ http :8001
```

### Up - down - start - stop

Usually, containers are assumed to disappear, so up and down mean create and
destroy respectively. To get a closer thing to vagrant, we want start and stop.
Gojira has a command to proxy commands to compose, we can stop and start
our setups as:

```
$ gojira compose stop
$ gojira compose -p cassandra stop
...
$ gojira compose start
$ gojira compose -p cassandra start
```

### PS: Something new and exciting

Let's say we are doing some ground breaking important work on our branch, and
whilst drinking some coffee, we decide we would like to pause and check a PR
that looks nice. Because we are extra-nice, we not only read the PR, we also
test it locally. But we do not want to lose too much focus on what we were
doing. This is gojira!

```
$ gojira up -t name/of-the-branch
$ gojira run -t name/of-the-branch foo
$ gojira run -t name/of-the-branch bar
$ gojira down -t name/of-the-branch
...
# And our environment is still completely safe where it was
$ gojira run http :8001
```

Happy hacking!
