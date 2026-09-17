ARG ALEVIN_FRY_VERSION=0.18.3
ARG ALEVIN_FRY_TAG=v0.18.3
ARG ALEVIN_FRY_COMMIT=ad05742d274230f9141b2eabeebd1c1b31692199
ARG ALEVIN_FRY_AMD64_SHA256=8f0d1d61643f8224b4267fffc106eee8639cedd7e66c5776d15ec6a25806d652
ARG ALEVIN_FRY_ARM64_SHA256=e00184a2417706cfb4ff906bbf3b42a8e1beca4272f9983dbf8c8328176bf7b8
ARG DEBIAN_BASE_DIGEST=sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241

FROM debian:12-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241 AS fetch

ARG TARGETARCH
ARG BUILDARCH
ARG BUILDPLATFORM
ARG ALEVIN_FRY_VERSION
ARG ALEVIN_FRY_TAG
ARG ALEVIN_FRY_COMMIT
ARG ALEVIN_FRY_AMD64_SHA256
ARG ALEVIN_FRY_ARM64_SHA256
ARG DEBIAN_BASE_DIGEST

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    installed=0; \
    for attempt in 1 2 3; do \
      if apt-get -o Acquire::Retries=5 update && \
         apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
           ca-certificates curl xz-utils; then \
        installed=1; \
        break; \
      fi; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    [ "${installed}" -eq 1 ]; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/alevin-fry-build

RUN set -eux; \
    BUILDARCH="${BUILDARCH:-${BUILDPLATFORM#linux/}}"; \
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
      printf "base_image=debian:12-slim@%s\n" "${DEBIAN_BASE_DIGEST}"; \
      printf "upstream_x86_64_cpu=x86-64-v3,+avx2\n"; \
      printf "upstream_aarch64_cpu=neoverse-n1\n"; \
      printf "upstream_license=BSD-3-Clause\n"; \
      printf "bundled_database=none\n"; \
      printf "runtime_network_required=no\n"; \
    } > /opt/alevin-fry/share/doc/alevin-fry/source.txt; \
    if [ "${BUILDARCH}" = "${TARGETARCH}" ]; then \
      /opt/alevin-fry/bin/alevin-fry --version 2>&1 | grep -Fx "alevin-fry ${ALEVIN_FRY_VERSION}" >/dev/null; \
    fi

FROM debian:12-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241

ARG ALEVIN_FRY_VERSION
ARG TARGETARCH
ARG BUILDARCH
ARG BUILDPLATFORM

LABEL org.opencontainers.image.title="alevin-fry" \
      org.opencontainers.image.description="TAFFISH wrapper for alevin-fry single-cell RNA-seq and ATAC-seq RAD processing" \
      org.opencontainers.image.source="https://github.com/COMBINE-lab/alevin-fry" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV PATH=/opt/alevin-fry/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=fetch /opt/alevin-fry /opt/alevin-fry
COPY docker/alevin-fry-smoke.sh /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh
COPY docker/alevin-fry-allowlist.sh /opt/alevin-fry/bin/alevin-fry-allowlist

RUN set -eux; \
    BUILDARCH="${BUILDARCH:-${BUILDPLATFORM#linux/}}"; \
    ln -s /opt/alevin-fry/bin/alevin-fry /usr/local/bin/alevin-fry; \
    chmod 0755 /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh; \
    chmod 0755 /opt/alevin-fry/bin/alevin-fry-allowlist; \
    sh -n /opt/alevin-fry/bin/alevin-fry-allowlist; \
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
