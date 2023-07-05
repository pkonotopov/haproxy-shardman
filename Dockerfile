FROM arm64v8/haproxy:latest

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    CRYPTO_LIBDIR=/usr/lib/aarch64-linux-gnu \
    OPENSSL_LIBDIR=/usr/lib/aarch64-linux-gnu \
    CRYPTO_INCDIR=/usr/include

RUN set -eux \
    && apt update \
    && apt install -y lua5.3 liblua5.3-dev luarocks libssl-dev socat \
    && luarocks install lpeg \
    && luarocks install pgmoon \
    && luarocks install luaossl CRYPTO_LIBDIR=${CRYPTO_LIBDIR} OPENSSL_LIBDIR=${OPENSSL_LIBDIR} CRYPTO_INCDIR=${CRYPTO_INCDIR} \
    && luarocks install luacrypto --only-deps CRYPTO_LIBDIR=${CRYPTO_LIBDIR} OPENSSL_LIBDIR=${OPENSSL_LIBDIR} CRYPTO_INCDIR=${CRYPTO_INCDIR} \
    && mkdir -p /etc/haproxy /var/run/haproxy \
    && chown haproxy:haproxy -R /etc/haproxy /var/run/haproxy \
    && apt-get purge -y --allow-remove-essential --allow-change-held-packages \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    /root/.cache \
    /var/cache/debconf/* \
    /usr/share/doc* \
    /usr/share/man \
    /tmp/*.deb \
    && find /var/log -type f -exec truncate --size 0 {} \;

EXPOSE 5432
EXPOSE 7001

USER haproxy

CMD ["/usr/local/sbin/haproxy","-f","/etc/haproxy/haproxy.cfg","-p","/var/run/haproxy/haproxy.pid","-W","-S","/tmp/haproxy-master.sock"]