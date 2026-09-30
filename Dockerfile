# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.22

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS download
ARG TARGETARCH
RUN apk add --no-cache curl
WORKDIR /out
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) hev_arch=x86_64 ;; \
      arm64) hev_arch=arm64 ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o hev-socks5-server \
      "https://github.com/heiher/hev-socks5-server/releases/download/2.11.0/hev-socks5-server-linux-${hev_arch}"; \
    curl -fL --retry 3 -o wgcf \
      "https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_linux_${TARGETARCH}"; \
    chmod 0755 hev-socks5-server wgcf

FROM alpine:${ALPINE_VERSION}
RUN apk add --no-cache ca-certificates iproute2 wireguard-tools bash

COPY --from=download /out/hev-socks5-server /out/wgcf /usr/local/bin/
COPY hev.yml /etc/hev.yml
COPY --chmod=0755 start.sh /start.sh

WORKDIR /data
VOLUME ["/data"]
EXPOSE 1080/tcp
EXPOSE 20000-20099/udp

ENTRYPOINT ["/start.sh"]
