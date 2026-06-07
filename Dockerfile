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

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY afp.conf /etc/afp.conf
ENV DEBIAN_FRONTEND newt

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "/usr/sbin/netatalk", "-F","/etc/afp.conf","-d"]