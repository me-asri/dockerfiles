FROM alpine:3.19 AS builder

RUN apk --no-cache add gcc musl-dev make patch linux-headers bsd-compat-headers autoconf automake libtool m4 pkgconf

WORKDIR /build/openssl
RUN wget -qO- https://www.openssl.org/source/openssl-3.2.1.tar.gz \
    | tar --strip-components 1 -xzf -
RUN ./config --prefix=/build/openssl/install no-shared no-tests no-legacy \
    && make -j$(nproc) \
    && make install_sw \
    && ln -s /build/openssl/install/lib64 /build/openssl/install/lib

WORKDIR /build/pcre2
RUN wget -qO- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.gz \
    | tar --strip-components 1 -xzf -
RUN ./configure --prefix=/build/pcre2/install --enable-static --disable-shared --enable-jit \
    && make -j$(nproc) \
    && make install

WORKDIR /build/nettle
RUN wget -qO- https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz \
    | tar --strip-components 1 -xzf -
RUN ./configure --prefix=/build/nettle/install --enable-static --disable-shared --enable-x86-aesni --enable-x86-sha-ni --enable-x86-pclmul \
    && make -j$(nproc) \
    && make install

WORKDIR /build/zlib
RUN wget -qO- https://www.zlib.net/zlib-1.3.1.tar.gz \
    | tar --strip-components 1 -xzf -
RUN ./configure --prefix=/build/zlib/install --static \
    && make -j$(nproc) \
    && make install \
    && ln -s /build/zlib/install/include/* /build/zlib/install/ \
    && ln -s /build/zlib/install/lib/* /build/zlib/install/

WORKDIR /build/brotli
RUN wget -qO- https://github.com/google/brotli/archive/refs/tags/v1.0.9.tar.gz \
    | tar --strip-components 1 -xzf -
RUN ./bootstrap \
    && ./configure --prefix=/build/brotli/install --enable-static --disable-shared \
    && make -j$(nproc) \
    && make install\
    && ln -s /build/brotli/install/include/* /build/zlib/install/ \
    && ln -s /build/brotli/install/lib/* /build/brotli/install/

WORKDIR /build/lighttpd
RUN wget -qO- https://download.lighttpd.net/lighttpd/releases-1.4.x/lighttpd-1.4.73.tar.gz \
    | tar --strip-components 1 -xzf -

COPY src/* /build/lighttpd/src/
COPY patch/ /build/lighttpd/patch

# Workaround for static build
RUN mv /usr/bin/gcc /usr/bin/_gcc \
    && echo -e $'#!/bin/sh\n/usr/bin/_gcc -static $*' > /usr/bin/gcc \
    && chmod +x /usr/bin/gcc

RUN find patch/ -name *.patch -print0 | xargs -t -n1 -0 patch -p1 -i
RUN LIGHTTPD_STATIC=yes ./configure -C --prefix=/opt/lighttpd --enable-static --disable-shared --with-openssl=/build/openssl/install --with-pcre2=/build/pcre2/install --with-nettle=/build/nettle/install --with-zlib=/build/zlib/install --with-brotli=/build/brotli/install \
    && make -j$(nproc) \
    && make install \
    && strip -s /opt/lighttpd/sbin/*

FROM busybox:1.36.1-musl

COPY --from=builder /opt/lighttpd /opt/lighttpd

COPY lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY modules.conf /etc/lighttpd/modules.conf
COPY conf.d /etc/lighttpd/conf.d

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN install -d -o www-data -g www-data /var/www/htdocs /var/cache/lighttpd /var/tmp/lighttpd

ENV LIGHTTPD_PORT 80
ENV LIGHTTPD_TLS_PORT 443

ENV LIGHTTPD_USER www-data
ENV LIGHTTPD_GROUP www-data

ENTRYPOINT [ "/usr/local/bin/docker-entrypoint.sh", "lighttpd" ]
