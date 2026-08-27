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

# netatalk 4.5 hard-depends on the Spotlight stack (localsearch/tinysparql),
# which needs a D-Bus session bus. Left to apt, that pulls dbus-user-session ->
# libpam-systemd -> systemd, whose postinst hangs/segfaults under QEMU during
# the multi-arch build (and systemd is never run in this container). Installing
# dbus-x11 -- which also provides default-dbus-session-bus -- satisfies that
# dependency without dragging in systemd. The guard below fails the build if
# real systemd is ever pulled in again, so this stays honest over time.
RUN apt-get update \
    && apt-get install \
        --no-install-recommends \
        --fix-missing \
        --assume-yes \
        $PERSISTENT_RUNTIME_DEPS \
        dbus-x11 \
        elogind \
        avahi-daemon \
        curl \
        ca-certificates \
        xz-utils \
        netatalk \
    \
    && apt-get --assume-yes upgrade \
    && if dpkg-query -W -f='${Status}\n' systemd 2>/dev/null | grep -q '^install ok installed'; then \
           echo "ERROR: the systemd package is installed; something still pulls it in."; \
           echo "Installed packages that depend on systemd:"; \
           apt-cache rdepends --installed systemd; \
           echo "--- their systemd/logind dependency lines ---"; \
           for p in $(apt-cache rdepends --installed systemd | tail -n +3 | tr -d ' |'); do \
               echo "## $p:"; \
               apt-cache show "$p" 2>/dev/null | grep -iE '^(Pre-)?Depends:' | grep -iE 'systemd|logind' || true; \
           done; \
           exit 1; \
       fi \
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

# Install s6-overlay as PID 1 so the container properly supervises its services
# (dbus, avahi, netatalk): zombie reaping, signal forwarding, restart-on-crash.
# Replaces the old single-process docker-entrypoint.sh.
ARG S6_OVERLAY_VERSION=3.2.1.0
ARG TARGETARCH
ARG TARGETVARIANT
RUN set -eux \
    && case "${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" in \
        amd64)   s6_arch=x86_64      ;; \
        arm64)   s6_arch=aarch64     ;; \
        arm/v7)  s6_arch=arm         ;; \
        386)     s6_arch=i686        ;; \
        ppc64le) s6_arch=powerpc64le ;; \
        s390x)   s6_arch=s390x       ;; \
        riscv64) s6_arch=riscv64     ;; \
        *) echo "unsupported target arch: ${TARGETARCH}${TARGETVARIANT}" >&2; exit 1 ;; \
    esac \
    && base="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}" \
    && curl -fsSL "${base}/s6-overlay-noarch.tar.xz"     -o /tmp/s6-noarch.tar.xz \
    && curl -fsSL "${base}/s6-overlay-${s6_arch}.tar.xz" -o /tmp/s6-arch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-arch.tar.xz \
    && rm -f /tmp/s6-noarch.tar.xz /tmp/s6-arch.tar.xz

# s6 service definitions: cont-init.d one-shots + supervised services.d daemons.
COPY root/ /
COPY afp.conf /etc/afp.conf
RUN chmod -R 0755 /etc/cont-init.d /etc/services.d

# Abort the boot if one-time init (cont-init.d) fails, instead of running half-up.
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

ENTRYPOINT ["/init"]