FROM debian:jessie

MAINTAINER suport.gencat@gencat.cat
#Aquesta imatge es basa en la imatge oficial de APACHE https://hub.docker.com/_/httpd/

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r httpd && useradd -r -g httpd httpd

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown httpd:httpd "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

# install httpd runtime dependencies
# https://httpd.apache.org/docs/2.4/install.html#requirements
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		libapr1 \
		libaprutil1 \
		libaprutil1-ldap \
		libapr1-dev \
		libaprutil1-dev \
		libpcre++0 \
		libssl1.0.0 \
	&& rm -r /var/lib/apt/lists/*

ENV HTTPD_VERSION 2.4.25
ENV HTTPD_SHA1 bd6d138c31c109297da2346c6e7b93b9283993d2
ENV HTTPD_BZ2_URL https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.bz2

RUN set -x \
	&& buildDeps=' \
		bzip2 \
		ca-certificates \
		gcc \
		libpcre++-dev \
		libssl-dev \
		make \
		wget \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -r /var/lib/apt/lists/* \
	\
	&& wget -O httpd.tar.bz2 "$HTTPD_BZ2_URL" \
	&& echo "$HTTPD_SHA1 *httpd.tar.bz2" | sha1sum -c - \
# see https://httpd.apache.org/download.cgi#verify
	&& wget -O httpd.tar.bz2.asc "$HTTPD_BZ2_URL.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys A93D62ECC3C8EA12DB220EC934EA76E6791485A8 \
	&& gpg --batch --verify httpd.tar.bz2.asc httpd.tar.bz2 \
	&& rm -r "$GNUPGHOME" httpd.tar.bz2.asc \
	\
	&& mkdir -p src \
	&& tar -xvf httpd.tar.bz2 -C src --strip-components=1 \
	&& rm httpd.tar.bz2 \
	&& cd src \
	\
	&& ./configure \
		--prefix="$HTTPD_PREFIX" \
		--enable-mods-shared=reallyall \
	&& make -j"$(nproc)" \
	&& make install \
	\
	&& cd .. \
	&& rm -r src \
	\
	&& sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		"$HTTPD_PREFIX/conf/httpd.conf" \
	\
	&& apt-get purge -y --auto-remove $buildDeps

COPY httpd-foreground /usr/local/bin/

RUN chmod 0755 /usr/local/bin/httpd-foreground

COPY httpd.conf $HTTPD_PREFIX/conf/

RUN mkdir -p /data && chown -R httpd:httpd /data \
   && test "$(id httpd)" = "uid=999(httpd) gid=999(httpd) groups=999(httpd)"

COPY docker-setup.sh /
RUN chmod 0755 /docker-setup.sh
RUN /docker-setup.sh
	
VOLUME /data

#Fitxer d'entrada
COPY run.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

#Copiem el fitxer wait-for-it
COPY wait-for-it.sh /
RUN chmod 0755 /wait-for-it.sh

EXPOSE 80

CMD ["/entrypoint.sh"]