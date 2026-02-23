FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY dist/*.deb /tmp/

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates; \
    deb_file="$(ls /tmp/*.deb | head -n 1)"; \
    test -n "${deb_file}"; \
    dpkg -i "${deb_file}" || apt-get install -y -f; \
    rm -rf /var/lib/apt/lists/* /tmp/*.deb

ENTRYPOINT ["/usr/bin/reverse"]
