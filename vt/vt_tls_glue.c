#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/net_sockets.h"
#include "mbedtls/sha256.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef struct {
    mbedtls_ssl_context      ssl;
    mbedtls_ssl_config       conf;
    mbedtls_entropy_context  entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_net_context      net;
} vt_tls_conn;

/* connect: sock = already-connected Win32 socket (from vt_net_connect)  */
/* returns opaque ptr on success, NULL on failure                         */
vt_tls_conn* vt_tls_open(int sock, const char* hostname)
{
    vt_tls_conn* c = (vt_tls_conn*)malloc(sizeof(vt_tls_conn));
    if (!c) return NULL;

    mbedtls_ssl_init        (&c->ssl);
    mbedtls_ssl_config_init (&c->conf);
    mbedtls_entropy_init    (&c->entropy);
    mbedtls_ctr_drbg_init   (&c->ctr_drbg);

    int ret;

    ret = mbedtls_ctr_drbg_seed(&c->ctr_drbg, mbedtls_entropy_func,
                                 &c->entropy,
                                 (const unsigned char*)"vtgem", 5);
    if (ret != 0) goto fail;

    ret = mbedtls_ssl_config_defaults(&c->conf,
                                       MBEDTLS_SSL_IS_CLIENT,
                                       MBEDTLS_SSL_TRANSPORT_STREAM,
                                       MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) goto fail;

    /* TOFU model: we accept any cert, fingerprint checked from FB side */
    mbedtls_ssl_conf_authmode(&c->conf, MBEDTLS_SSL_VERIFY_NONE);
    mbedtls_ssl_conf_rng     (&c->conf, mbedtls_ctr_drbg_random, &c->ctr_drbg);

    ret = mbedtls_ssl_setup(&c->ssl, &c->conf);
    if (ret != 0) goto fail;

    /* SNI: send hostname in handshake so vhosts work */
    ret = mbedtls_ssl_set_hostname(&c->ssl, hostname);
    if (ret != 0) goto fail;

    /* hand our already-connected socket to mbed TLS */
    c->net.fd = sock;
    mbedtls_ssl_set_bio(&c->ssl, &c->net,
                         mbedtls_net_send, mbedtls_net_recv, NULL);

    do { ret = mbedtls_ssl_handshake(&c->ssl); }
    while (ret == MBEDTLS_ERR_SSL_WANT_READ ||
           ret == MBEDTLS_ERR_SSL_WANT_WRITE);
    if (ret != 0) goto fail;

    return c;

fail:
    mbedtls_ssl_free        (&c->ssl);
    mbedtls_ssl_config_free (&c->conf);
    mbedtls_entropy_free    (&c->entropy);
    mbedtls_ctr_drbg_free   (&c->ctr_drbg);
    free(c);
    return NULL;
}

/* write: returns bytes sent, -1 on error */
int vt_tls_write(vt_tls_conn* c, const unsigned char* buf, int nbytes)
{
    int ret;
    do { ret = mbedtls_ssl_write(&c->ssl, buf, (size_t)nbytes); }
    while (ret == MBEDTLS_ERR_SSL_WANT_WRITE);
    return (ret < 0) ? -1 : ret;
}

/* read: returns bytes read, 0 = no data yet, -1 = closed, -2 = error  */
int vt_tls_read(vt_tls_conn* c, unsigned char* buf, int nbytes)
{
    int ret = mbedtls_ssl_read(&c->ssl, buf, (size_t)nbytes);
    if (ret == MBEDTLS_ERR_SSL_WANT_READ ||
        ret == MBEDTLS_ERR_SSL_WANT_WRITE)   return  0;
    if (ret == 0 ||
        ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) return -1;
    if (ret  < 0)                              return -2;
    return ret;
}

/* fingerprint: SHA-256 of peer cert DER, written as 64 hex chars + NUL */
/* out_hex must be >= 65 bytes.  returns 0 ok, -1 no peer cert           */
int vt_tls_peer_fingerprint(vt_tls_conn* c, char* out_hex)
{
    const mbedtls_x509_crt* cert = mbedtls_ssl_get_peer_cert(&c->ssl);
    if (!cert) return -1;

    unsigned char sha[32];
    mbedtls_sha256_ret(cert->raw.p, cert->raw.len, sha, 0);

    int i;
    for (i = 0; i < 32; i++)
        sprintf(out_hex + i * 2, "%02x", (unsigned)sha[i]);
    out_hex[64] = 0;
    return 0;
}

/* close and free everything */
void vt_tls_close(vt_tls_conn* c)
{
    if (!c) return;
    mbedtls_ssl_close_notify(&c->ssl);
    mbedtls_ssl_free        (&c->ssl);
    mbedtls_ssl_config_free (&c->conf);
    mbedtls_entropy_free    (&c->entropy);
    mbedtls_ctr_drbg_free   (&c->ctr_drbg);
    free(c);
}