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

# systemd is only a transitive dependency and is never run in this container
# (the entrypoint launches netatalk directly). Its postinst maintainer script
# hangs or segfaults under QEMU user-mode emulation during the multi-arch
# build, so stub the helpers it invokes (via dpkg-divert) for the duration of
# the install, then restore the real binaries afterwards.
RUN set -eux \
    && printf '#!/bin/sh\nexit 0\n' > /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d \
    && for b in systemctl systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-machine-id-setup; do \
           dpkg-divert --local --rename --add "/usr/bin/$b"; \
           ln -sf /bin/true "/usr/bin/$b"; \
       done \
    && apt-get update \
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
    && for b in systemctl systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-machine-id-setup; do \
           rm -f "/usr/bin/$b"; \
           dpkg-divert --local --rename --remove "/usr/bin/$b"; \
       done \
    && rm -f /usr/sbin/policy-rc.d \
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