/**
 * Copyright 2019 Kong Inc.

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 *    http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>


#if (NGX_SSL)
static int ngx_http_lua_kong_ssl_old_sess_new_cb_index = -1;
static int ngx_http_lua_kong_ssl_no_session_cache_flag_index = -1;


static int
ngx_http_lua_kong_verify_callback(int ok, X509_STORE_CTX *x509_store);
#endif
static ngx_int_t ngx_http_lua_kong_init(ngx_conf_t *cf);


static ngx_http_module_t ngx_http_lua_kong_module_ctx = {
    NULL,                                    /* preconfiguration */
    ngx_http_lua_kong_init,                  /* postconfiguration */

    NULL,                                    /* create main configuration */
    NULL,                                    /* init main configuration */

    NULL,                                    /* create server configuration */
    NULL,                                    /* merge server configuration */

    NULL,                                    /* create location configuration */
    NULL                                     /* merge location configuration */
};


ngx_module_t ngx_http_lua_kong_module = {
    NGX_MODULE_V1,
    &ngx_http_lua_kong_module_ctx,     /* module context */
    NULL,                              /* module directives */
    NGX_HTTP_MODULE,                   /* module type */
    NULL,                              /* init master */
    NULL,                              /* init module */
    NULL,                              /* init process */
    NULL,                              /* init thread */
    NULL,                              /* exit thread */
    NULL,                              /* exit process */
    NULL,                              /* exit master */
    NGX_MODULE_V1_PADDING
};


static ngx_int_t
ngx_http_lua_kong_init(ngx_conf_t *cf)
{
#if (NGX_SSL)
    if (ngx_http_lua_kong_ssl_old_sess_new_cb_index == -1) {
        ngx_http_lua_kong_ssl_old_sess_new_cb_index =
            SSL_CTX_get_ex_new_index(0, NULL, NULL, NULL, NULL);

        if (ngx_http_lua_kong_ssl_old_sess_new_cb_index == -1) {
            ngx_ssl_error(NGX_LOG_ALERT, cf->log, 0,
                          "kong: SSL_CTX_get_ex_new_index() for ssl ctx failed");
            return NGX_ERROR;
        }
    }

    if (ngx_http_lua_kong_ssl_no_session_cache_flag_index == -1) {
        ngx_http_lua_kong_ssl_no_session_cache_flag_index =
            SSL_get_ex_new_index(0, NULL, NULL, NULL, NULL);

        if (ngx_http_lua_kong_ssl_no_session_cache_flag_index == -1) {
            ngx_ssl_error(NGX_LOG_ALERT, cf->log, 0,
                          "kong: SSL_get_ex_new_index() for ssl failed");
            return NGX_ERROR;
        }
    }
#endif

    return NGX_OK;
}


#if (NGX_SSL)
static int
ngx_http_lua_kong_verify_callback(int ok, X509_STORE_CTX *x509_store)
{
    /* similar to ngx_ssl_verify_callback, always allow handshake
     * to conclude before deciding the validity of client certificate */
    return 1;
}


static int
ngx_http_lua_kong_new_session(ngx_ssl_conn_t *ssl_conn, ngx_ssl_session_t *sess)
{
    ngx_uint_t      flag;

    flag = (ngx_uint_t) SSL_get_ex_data(ssl_conn,
                            ngx_http_lua_kong_ssl_no_session_cache_flag_index);

    if (flag) {
        return 0;
    }

    return ((int (*)(SSL *ssl, SSL_SESSION *sess))
               SSL_CTX_get_ex_data(SSL_get_SSL_CTX(ssl_conn),
                   ngx_http_lua_kong_ssl_old_sess_new_cb_index))(ssl_conn,
                                                                 sess);
}
#endif


/*
 * disables session reuse for the current TLS connection, must be called
 * in ssl_certby_lua* phase
 */

const char *
ngx_http_lua_kong_ffi_disable_session_reuse(ngx_http_request_t *r)
{
#if (NGX_SSL)
    ngx_uint_t           flag;
    ngx_connection_t    *c = r->connection;
    ngx_ssl_conn_t      *sc;
    SSL_CTX             *ctx;

    if (c->ssl == NULL) {
        return "server does not have TLS enabled";
    }

    sc = c->ssl->connection;

    /* the following disables session ticket for the current connection */
    SSL_set_options(sc, SSL_OP_NO_TICKET);

    /* the following disables session cache for the current connection
     * note that we are using the pointer storage to store a flag value to
     * avoid having to do memory allocations. since the pointer is never
     * dereferenced this is completely safe to do */
    flag = 1;

    if (SSL_set_ex_data(sc,
                        ngx_http_lua_kong_ssl_no_session_cache_flag_index,
                        (void *) flag) == 0)
    {
        return "unable to disable session cache for current connection";
    }

    ctx = c->ssl->session_ctx;

    /* hook session_new_cb if not already done so */
    if (SSL_CTX_sess_get_new_cb(ctx) !=
        ngx_http_lua_kong_new_session)
    {
        /* save old callback */
        if (SSL_CTX_set_ex_data(ctx,
                                ngx_http_lua_kong_ssl_old_sess_new_cb_index,
                                SSL_CTX_sess_get_new_cb(ctx)) == 0)
        {
            return "unable to install new session hook";
        }

        /* install hook */
        SSL_CTX_sess_set_new_cb(ctx, ngx_http_lua_kong_new_session);
    }

    return NULL;

#else
    return "TLS support is not enabled in Nginx build"
#endif
}


/*
 * request downstream to present a client certificate during TLS handshake,
 * but does not validate it
 *
 * this is roughly equivalent to setting ssl_verify_client to optional_no_ca
 *
 * on success, NULL is returned, otherwise a static string indicating the
 * failure reason is returned
 */

const char *
ngx_http_lua_kong_ffi_request_client_certificate(ngx_http_request_t *r)
{
#if (NGX_SSL)
    ngx_connection_t    *c = r->connection;
    ngx_ssl_conn_t      *sc;
    SSL_CTX             *ctx;

    if (c->ssl == NULL) {
        return "server does not have TLS enabled";
    }

    sc = c->ssl->connection;

    SSL_set_verify(sc, SSL_VERIFY_PEER, ngx_http_lua_kong_verify_callback);

    return NULL;

#else
    return "TLS support is not enabled in Nginx build"
#endif
}


int
ngx_http_lua_kong_ffi_get_full_client_certificate_chain(ngx_http_request_t *r,
    char *buf, size_t *buf_len)
{
#if (NGX_SSL)
    ngx_connection_t    *c = r->connection;
    ngx_ssl_conn_t      *sc;
    STACK_OF(X509)      *chain;
    X509                *cert;
    int                  i, n;
    size_t               len;
    BIO                 *bio;
    int                  ret;

    if (c->ssl == NULL) {
        return NGX_ABORT;
    }

    sc = c->ssl->connection;

    cert = SSL_get_peer_certificate(c->ssl->connection);
    if (cert == NULL) {
        /* client did not present a certificate or server did not request it */
        return NGX_DECLINED;
    }

    bio = BIO_new(BIO_s_mem());
    if (bio == NULL) {
        ngx_ssl_error(NGX_LOG_ALERT, c->log, 0, "BIO_new() failed");

        X509_free(cert);
        ret = NGX_ERROR;
        goto done;
    }

    if (PEM_write_bio_X509(bio, cert) == 0) {
        ngx_ssl_error(NGX_LOG_ALERT, c->log, 0, "PEM_write_bio_X509() failed");

        X509_free(cert);
        ret = NGX_ERROR;
        goto done;
    }

    X509_free(cert);

    chain = SSL_get_peer_cert_chain(sc);
    if (chain == NULL) {
        ret = NGX_DECLINED;
        goto done;
    }

    n = sk_X509_num(chain);
    for (i = 0; i < n; i++) {
        cert = sk_X509_value(chain, i);

        if (PEM_write_bio_X509(bio, cert) == 0) {
            ngx_ssl_error(NGX_LOG_ALERT, c->log, 0, "PEM_write_bio_X509() failed");

            ret = NGX_ERROR;
            goto done;
        }
    }

    len = BIO_pending(bio);
    if (len > *buf_len) {
        *buf_len = len;

        ret = NGX_AGAIN;
        goto done;
    }

    BIO_read(bio, buf, len);
    *buf_len = len;

    ret = NGX_OK;

done:

    BIO_free(bio);

    return ret;

#else
    return NGX_ABORT;
#endif
}
