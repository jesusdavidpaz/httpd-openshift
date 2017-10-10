FROM debian:jessie

MAINTAINER suport.gencat@gencat.cat
#Aquesta imatge es basa en la imatge oficial de APACHE https://hub.docker.com/_/httpd/

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r httpd && useradd -r -g httpd httpd

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $PATH:$HTTPD_PREFIX/bin
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
		sudo \
	&& rm -r /var/lib/apt/lists/*

ENV HTTPD_VERSION 2.2.34
ENV HTTPD_BZ2_URL https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.bz2

RUN buildDeps=' \
		ca-certificates \
		curl \
		bzip2 \
		gcc \
		libpcre++-dev \
		libssl-dev \
		make \
	' \
	set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -r /var/lib/apt/lists/* \
	\
	&& curl -fSL "$HTTPD_BZ2_URL" -o httpd.tar.bz2 \
	&& curl -fSL "$HTTPD_BZ2_URL.asc" -o httpd.tar.bz2.asc \
# see https://httpd.apache.org/download.cgi#verify
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B1B96F45DFBDCCF974019235193F180AB55D9977 \
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
# https://httpd.apache.org/docs/2.2/programs/configure.html
# Caveat: --enable-mods-shared=all does not actually build all modules. To build all modules then, one might use:
		--enable-mods-shared='all ssl ldap cache proxy authn_alias mem_cache file_cache authnz_ldap charset_lite dav_lock disk_cache' \
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