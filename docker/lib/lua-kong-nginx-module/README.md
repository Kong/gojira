Name
====
lua-kong-nginx-module - Nginx C module that exposes a Lua API to dynamically control Nginx


Description
===========
Kong often needs to be able to change Nginx behavior at runtime. Traditionally this
has been done using various core patches. This module attempts to unify those approaches
and ensure the least amount of modifications made directly to Nginx to support future
maintainability.

Install
=======
This module can be installed just like any ordinary Nginx C module, using the
`--add-module` configuration option:

```shell
./configure --prefix=/usr/local/kong-nginx \
            --add-module=/path/to/lua-kong-nginx-module \
            ...

```

Methods
=======

resty.kong.tls.request\_client\_certificate
-------------------------------------------
**syntax:** *succ, err = resty.kong.tls.request\_client\_certificate()*

**context:** *ssl_certificate_by_lua&#42;*

Requests client to present its client-side certificate to initiate mutual TLS
authentication between server and client.

This function only *requests*, but does not *require* the client to start the mTLS
process. Even if the client did not present a client certificate the TLS handshake
will still complete (obviously not being mTLS in that case).
Whether the client honored the request can be determined using
[get\_full\_client\_certificate\_chain](#restykongtlsget_full_client_certificate_chain)
in later phases.

This function returns `true` when the call is successful. Otherwise it returns
`nil` and a string describing the error.

resty.kong.tls.disable\_session\_reuse
--------------------------------------
**syntax:** *succ, err = resty.kong.tls.disable\_session\_reuse()*

**context:** *ssl_certificate_by_lua&#42;*

Prevents the TLS session for the current connection from being reused by
disabling session ticket and session ID for the current TLS connection.

This function returns `true` when the call is successful. Otherwise it returns
`nil` and a string describing the error.


resty.kong.tls.get\_full\_client\_certificate\_chain
-------------------------------------------
**syntax:** *pem_chain, err = resty.kong.tls.get\_full\_client\_certificate\_chain()*

**context:** *rewrite_by_lua&#42;, access_by_lua&#42;, content_by_lua&#42;, log_by_lua&#42;*

Returns the PEM encoded downstream client certificate chain with the client certificate
at the top and intermediate certificates (if any) at the bottom.

If client did not present any certificate or if session was reused, then this
function will return `nil`.

This is functionally similar to
[$ssl\_client\_raw\_cert](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#var_ssl_client_raw_cert)
provided by [ngx\_http\_ssl\_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html),
with the notable exception that this function also returns any certificate chain
client sent during handshake.

If the TLS session was reused, (signaled by
[$ssl\_session\_reused](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#var_ssl_session_reused) returns "r"),
then no client certificate information will be available as a full handshake never occurred.
In this case caller should use
[$ssl\_session\_id](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#var_ssl_session_id) to
associate this session with one of the previous handshakes to identify the connecting
client.


License
=======

```
Copyright 2019 Kong Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
