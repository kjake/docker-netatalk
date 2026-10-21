# Netatalk is not packaged in Wolfi, so it is compiled from source in a build
# stage and only the installed files are copied into the runtime image.
#
# Wolfi packages are intentionally left unpinned so that every rebuild picks up
# the latest patched packages. Netatalk itself tracks the newest stable release
# of NETATALK_MAJOR unless NETATALK_VERSION is set, e.g.
#   docker build --build-arg NETATALK_VERSION=4.6.1 .
ARG NETATALK_MAJOR=4

FROM cgr.dev/chainguard/wolfi-base:latest AS build

ARG NETATALK_MAJOR
ARG NETATALK_VERSION=

RUN apk add --no-cache \
        avahi-dev \
        build-base \
        db-dev \
        git \
        iniparser-dev \
        libevent-dev \
        libgcrypt-dev \
        libxcrypt-dev \
        meson \
        pkgconf \
        samurai \
        sqlite-dev

RUN set -eu \
    && if [ -z "${NETATALK_VERSION}" ]; then \
        NETATALK_VERSION="$(git ls-remote --tags --refs https://github.com/Netatalk/netatalk.git "netatalk-${NETATALK_MAJOR}-*" \
            | sed -n "s|.*refs/tags/netatalk-\(${NETATALK_MAJOR}-[0-9]*-[0-9]*\)$|\1|p" \
            | sort -t- -k2,2n -k3,3n \
            | tail -n 1 \
            | tr - .)"; \
    fi \
    && test -n "${NETATALK_VERSION}" \
    && echo "Building netatalk ${NETATALK_VERSION}" \
    && git clone --depth 1 \
        --branch "netatalk-$(echo "${NETATALK_VERSION}" | tr . -)" \
        https://github.com/Netatalk/netatalk.git /netatalk

WORKDIR /netatalk

RUN meson setup build \
        --prefix=/usr \
        --libdir=lib \
        --sbindir=bin \
        --sysconfdir=/etc \
        --localstatedir=/var \
        -Dbuildtype=release \
        -Dwith-acls=false \
        -Dwith-cnid-backends=dbd,sqlite \
        -Dwith-cracklib=false \
        -Dwith-cups=false \
        -Dwith-docs= \
        -Dwith-dtrace=false \
        -Dwith-gssapi=false \
        -Dwith-init-style=none \
        -Dwith-kerberos=false \
        -Dwith-krbV-uam=false \
        -Dwith-ldap=false \
        -Dwith-pam=false \
        -Dwith-pkgconfdir-path=/etc/netatalk \
        -Dwith-quota=false \
        -Dwith-spotlight=false \
        -Dwith-statedir-path=/var/lib \
        -Dwith-tcp-wrappers=false \
    && meson compile -C build \
    && meson install -C build --destdir /staging \
    && test -x /staging/usr/bin/netatalk \
    && test -x /staging/usr/bin/cnid_dbd

FROM cgr.dev/chainguard/wolfi-base:latest
LABEL maintainer="kjake"

RUN apk add --no-cache \
        avahi \
        bash \
        db \
        dbus \
        iniparser \
        libevent \
        libgcrypt \
        libxcrypt \
        shadow \
        sqlite-libs \
    && for svc in messagebus avahi; do \
        id -u "${svc}" >/dev/null 2>&1 \
            || useradd --system --user-group --no-create-home --home-dir /nonexistent --shell /bin/false "${svc}"; \
    done \
    && mkdir -p /media/share /var/lock

COPY --from=build /staging/ /
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY afp.conf /etc/afp.conf

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "/usr/bin/netatalk", "-F","/etc/afp.conf","-d"]
