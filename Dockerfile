FROM kjake/base
LABEL maintainer="kjake"

ENV PERSISTENT_RUNTIME_DEPS \
    libwrap0 \
    libcrack2 \
    libavahi-client3 \
    libevent-2.1-7t64 \
    netbase \
    python3 \
    perl

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install \
        --no-install-recommends \
        --fix-missing \
        --assume-yes \
        $PERSISTENT_RUNTIME_DEPS \
        avahi-daemon \
        curl \
        ca-certificates \
        netatalk \
    \
    && apt-get --assume-yes upgrade \
    && apt-get --quiet --yes autoclean \
    && apt-get --quiet --yes autoremove \
    && apt-get --quiet --yes clean \
    && rm -rf /netatalk* \
    && rm -rf /usr/share/man \
    && rm -rf /usr/share/doc \
    && rm -rf /usr/share/icons \
    && rm -rf /usr/share/poppler \
    && rm -rf /usr/share/mime \
    && rm -rf /usr/share/GeoIP \
    && rm -rf /var/lib/apt/lists* \
    && rm -rf /var/log/* \
    && ln -s /usr/lib/netatalk /etc/netatalk/uams \
    && mkdir /media/share

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY afp.conf /etc/afp.conf
ENV DEBIAN_FRONTEND newt

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "/usr/sbin/netatalk", "-F","/etc/afp.conf","-d"]