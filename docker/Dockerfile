ARG ALEVIN_FRY_VERSION=0.16.2
ARG ALEVIN_FRY_TAG=v0.16.2
ARG ALEVIN_FRY_COMMIT=d812531ef1c5fd22efec98cfc26b6f443b138650
ARG ALEVIN_FRY_AMD64_SHA256=2dbbec0db1c3d569bc7b51ab4bffe5fd6c13bdf0d45b82932b970503d65893c1
ARG ALEVIN_FRY_ARM64_SHA256=867689d53a19858b5005257b9f737f2973b3fc8e1f97e819f81714e746f101fb
ARG BUILDARCH

FROM debian:12-slim AS fetch

ARG TARGETARCH
ARG BUILDARCH
ARG ALEVIN_FRY_VERSION
ARG ALEVIN_FRY_TAG
ARG ALEVIN_FRY_COMMIT
ARG ALEVIN_FRY_AMD64_SHA256
ARG ALEVIN_FRY_ARM64_SHA256

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get -o Acquire::Retries=5 update; \
    apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/alevin-fry-build

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        asset_arch="x86_64"; \
        asset_sha256="${ALEVIN_FRY_AMD64_SHA256}" \
        ;; \
      arm64) \
        asset_arch="aarch64"; \
        asset_sha256="${ALEVIN_FRY_ARM64_SHA256}" \
        ;; \
      *) \
        echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; \
        exit 1 \
        ;; \
    esac; \
    asset="alevin-fry-${asset_arch}-unknown-linux-gnu.tar.xz"; \
    asset_url="https://github.com/COMBINE-lab/alevin-fry/releases/download/${ALEVIN_FRY_TAG}/${asset}"; \
    curl --retry 5 --retry-delay 2 --retry-all-errors -fsSL "${asset_url}" -o release.tar.xz; \
    echo "${asset_sha256}  release.tar.xz" | sha256sum -c -; \
    tar -xJf release.tar.xz --strip-components=1; \
    test -s alevin-fry; \
    test -s LICENSE; \
    install -Dm0755 alevin-fry /opt/alevin-fry/bin/alevin-fry; \
    install -Dm0644 LICENSE /opt/alevin-fry/share/licenses/alevin-fry/LICENSE; \
    install -Dm0644 README.md /opt/alevin-fry/share/doc/alevin-fry/README.md; \
    install -Dm0644 CHANGELOG.md /opt/alevin-fry/share/doc/alevin-fry/CHANGELOG.md; \
    { \
      printf "upstream_name=alevin-fry\n"; \
      printf "upstream_repo=https://github.com/COMBINE-lab/alevin-fry\n"; \
      printf "upstream_version=%s\n" "${ALEVIN_FRY_VERSION}"; \
      printf "upstream_tag=%s\n" "${ALEVIN_FRY_TAG}"; \
      printf "upstream_commit=%s\n" "${ALEVIN_FRY_COMMIT}"; \
      printf "runtime_source=official GitHub release binary\n"; \
      printf "release_asset=%s\n" "${asset}"; \
      printf "release_asset_url=%s\n" "${asset_url}"; \
      printf "release_asset_sha256=%s\n" "${asset_sha256}"; \
      printf "linux_amd64_asset_sha256=%s\n" "${ALEVIN_FRY_AMD64_SHA256}"; \
      printf "linux_arm64_asset_sha256=%s\n" "${ALEVIN_FRY_ARM64_SHA256}"; \
      printf "target_arch=%s\n" "${TARGETARCH}"; \
      printf "build_arch=%s\n" "${BUILDARCH}"; \
      printf "upstream_x86_64_cpu=x86-64-v3,+avx2\n"; \
      printf "upstream_aarch64_cpu=neoverse-n1\n"; \
      printf "upstream_license=BSD-3-Clause\n"; \
      printf "bundled_database=none\n"; \
      printf "runtime_network_required=no\n"; \
    } > /opt/alevin-fry/share/doc/alevin-fry/source.txt; \
    if [ "${BUILDARCH}" = "${TARGETARCH}" ]; then \
      /opt/alevin-fry/bin/alevin-fry --version 2>&1 | grep -Fx "alevin-fry ${ALEVIN_FRY_VERSION}" >/dev/null; \
    fi

FROM debian:12-slim

ARG ALEVIN_FRY_VERSION
ARG TARGETARCH
ARG BUILDARCH

LABEL org.opencontainers.image.title="alevin-fry" \
      org.opencontainers.image.description="TAFFISH wrapper for alevin-fry single-cell RNA-seq and ATAC-seq RAD processing" \
      org.opencontainers.image.source="https://github.com/COMBINE-lab/alevin-fry" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV PATH=/opt/alevin-fry/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=fetch /opt/alevin-fry /opt/alevin-fry
COPY docker/alevin-fry-smoke.sh /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh

RUN set -eux; \
    ln -s /opt/alevin-fry/bin/alevin-fry /usr/local/bin/alevin-fry; \
    chmod 0755 /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh; \
    if [ "${BUILDARCH}" = "${TARGETARCH}" ]; then \
      alevin-fry --version 2>&1 | grep -Fx "alevin-fry ${ALEVIN_FRY_VERSION}" >/dev/null; \
      alevin-fry --help 2>&1 | grep -F "Process RAD files from the command line" >/dev/null; \
      ldd "$(command -v alevin-fry)" > /tmp/alevin-fry-ldd.txt; \
      if grep -F "not found" /tmp/alevin-fry-ldd.txt; then exit 1; fi; \
      /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh buildtime /tmp/taf-alevin-fry-build-check; \
    else \
      grep -Fx "target_arch=${TARGETARCH}" /opt/alevin-fry/share/doc/alevin-fry/source.txt >/dev/null; \
      test -x /opt/alevin-fry/bin/alevin-fry; \
    fi; \
    rm -rf /tmp/alevin-fry-ldd.txt /tmp/taf-alevin-fry-build-check

ENV TAFFISH_ENV=TAFFISH \
    TAFFISH_NAME=alevin-fry \
    TAFFISH_VERSION=${ALEVIN_FRY_VERSION} \
    TAFFISH_RELEASE=1

WORKDIR /root
