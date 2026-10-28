# The base digest fixes runtime bytes, not their future registry availability.
# Recover unavailable inputs from verified official bytes; never bypass checksums.
ARG ALEVIN_FRY_VERSION=0.19.0
ARG ALEVIN_FRY_TAG=v0.19.0
ARG ALEVIN_FRY_COMMIT=1117219ec9cbd070293df0a329a37d9fc44be44a
ARG ALEVIN_FRY_AMD64_SHA256=fb3e5ea646f4582bf550a91f25c2d5446a26b40caca2fe04a96780760c11d52c
ARG ALEVIN_FRY_ARM64_SHA256=b17b48f6fb14f1d35f3c3be2edecc18153422face40f586c65234df05e15c2b3
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

# Debian repositories are mutable: fetch-stage package versions may drift or vanish.
# Retry transient failures; review a successor snapshot/base if packages disappear.
# These build-only packages are not copied into the final runtime.
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

# A release URL may disappear or be replaced; the fixed SHA fails closed.
# Recheck the official tag and asset before any deliberate checksum update.
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
      printf "fetch_base_image=debian:12-slim@%s\n" "${DEBIAN_BASE_DIGEST}"; \
      printf "runtime_base_image=python:3.11-slim-bookworm@sha256:f06d01d4ba3f8ad5af45a3ec87df19c1d317d8e8961edc0fabda61811af6f7cf\n"; \
      printf "upstream_x86_64_cpu=x86-64-v3,+avx2\n"; \
      printf "upstream_aarch64_cpu=neoverse-n1\n"; \
      printf "upstream_license=BSD-3-Clause\n"; \
      printf "bundled_database=none\n"; \
      printf "runtime_network_required=no\n"; \
    } > /opt/alevin-fry/share/doc/alevin-fry/source.txt; \
    if [ "${BUILDARCH}" = "${TARGETARCH}" ]; then \
      /opt/alevin-fry/bin/alevin-fry --version 2>&1 | grep -Fx "alevin-fry ${ALEVIN_FRY_VERSION}" >/dev/null; \
    fi

# Preserve complete, unmodified QCatch source with the mixed-license notice.
RUN mkdir -p /opt/alevin-fry/share/sources && \
    curl --retry 5 --retry-all-errors -fsSL \
      https://files.pythonhosted.org/packages/bb/64/dce16ffa467a9760a3c4f6e4ec54d81354fe4902be6d7bb1080e1b8165c5/qcatch-0.2.14.tar.gz \
      -o /opt/alevin-fry/share/sources/qcatch-0.2.14.tar.gz && \
    echo '0dbb13452436bbcc69903da95206eebbfa272a516e0f83e002c96c519d031e38  /opt/alevin-fry/share/sources/qcatch-0.2.14.tar.gz' | sha256sum -c -

FROM python:3.11-slim-bookworm@sha256:f06d01d4ba3f8ad5af45a3ec87df19c1d317d8e8961edc0fabda61811af6f7cf AS qcatch-runtime

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
# The Debian mirror can rotate libgomp packages; Python and wheel bytes are fixed.
# Missing artifacts require a reviewed source update, not relaxed hash verification.
RUN apt-get -o Acquire::Retries=5 update && \
    apt-get -o Acquire::Retries=5 install -y --no-install-recommends libgomp1 && \
    rm -rf /var/lib/apt/lists/*
COPY docker/qcatch-*.lock /tmp/qcatch-locks/
# PyPI retention and CDN availability are external; exact wheels fail closed.
# Archive/restore the same approved bytes, or review dependency changes explicitly.
RUN --mount=type=cache,id=qcatch-pip-${TARGETARCH},target=/root/.cache/pip \
    set -eux; python3 -m venv /opt/qcatch; \
    installed=0; \
    for attempt in 1 2 3; do \
      if /opt/qcatch/bin/python3 -m pip install --only-binary=:all: --timeout 120 \
        --require-hashes -r /tmp/qcatch-locks/qcatch-${TARGETARCH}.lock; then \
        installed=1; break; \
      fi; \
      sleep 3; \
    done; \
    [ "${installed}" -eq 1 ] && \
    /opt/qcatch/bin/python3 -m pip check && \
    mkdir -p /opt/alevin-fry/share/doc/qcatch && \
    /opt/qcatch/bin/python3 -m pip freeze > /opt/alevin-fry/share/doc/qcatch/packages.txt && \
    cp /tmp/qcatch-locks/qcatch-${TARGETARCH}.lock /opt/alevin-fry/share/doc/qcatch/requirements.lock && \
    rm -rf /tmp/qcatch-locks
COPY docker/qcatch-assets.json docker/fetch-qcatch-assets.py /tmp/qcatch-fetch/
# CDN URLs may disappear; assets.json records fixed versions and content hashes.
RUN python3 /tmp/qcatch-fetch/fetch-qcatch-assets.py /tmp/qcatch-fetch/qcatch-assets.json \
      /opt/alevin-fry/share/qcatch-assets && rm -rf /tmp/qcatch-fetch

FROM qcatch-runtime

ARG ALEVIN_FRY_VERSION
ARG TARGETARCH
ARG BUILDARCH
ARG BUILDPLATFORM

LABEL org.opencontainers.image.title="alevin-fry" \
      org.opencontainers.image.description="TAFFISH wrapper for alevin-fry single-cell RNA-seq and ATAC-seq RAD processing" \
      org.opencontainers.image.source="https://github.com/COMBINE-lab/alevin-fry" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV PATH=/opt/alevin-fry/bin:/opt/qcatch/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PYTHONDONTWRITEBYTECODE=1

COPY --from=fetch /opt/alevin-fry /opt/alevin-fry
COPY docker/alevin-fry-smoke.sh /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh
COPY docker/alevin-fry-allowlist.sh /opt/alevin-fry/bin/alevin-fry-allowlist
COPY THIRD_PARTY_LICENSES /opt/alevin-fry/share/licenses/THIRD_PARTY_LICENSES
COPY docker/licenses/ /opt/alevin-fry/share/licenses/qcatch/
COPY docker/qcatch-local.py /opt/alevin-fry/bin/qcatch
COPY docker/qcatch-offline.py /opt/alevin-fry/bin/qcatch-offline
COPY docker/qcatch-gene-map.sh /opt/alevin-fry/bin/qcatch-gene-map
COPY docker/qcatch-smoke.py /opt/alevin-fry/share/testdata/qcatch-smoke.py

RUN set -eux; \
    BUILDARCH="${BUILDARCH:-${BUILDPLATFORM#linux/}}"; \
    chmod 0755 /opt /opt/alevin-fry /opt/alevin-fry/bin /opt/alevin-fry/share \
      /opt/alevin-fry/share/testdata /opt/alevin-fry/share/licenses \
      /opt/alevin-fry/share/licenses/alevin-fry /opt/alevin-fry/share/doc \
      /opt/alevin-fry/share/doc/alevin-fry; \
    chmod 0644 /opt/alevin-fry/share/licenses/THIRD_PARTY_LICENSES; \
    ln -s /opt/alevin-fry/bin/alevin-fry /usr/local/bin/alevin-fry; \
    chmod 0755 /opt/alevin-fry/share/testdata/alevin-fry-smoke.sh; \
    chmod 0755 /opt/alevin-fry/bin/alevin-fry-allowlist; \
    chmod 0755 /opt/alevin-fry/bin/qcatch /opt/alevin-fry/bin/qcatch-offline \
      /opt/alevin-fry/bin/qcatch-gene-map /opt/alevin-fry/share/testdata/qcatch-smoke.py; \
    find /opt/alevin-fry/share -type d -exec chmod 0755 {} +; \
    find /opt/alevin-fry/share/licenses /opt/alevin-fry/share/qcatch-assets -type f -exec chmod 0644 {} +; \
    sh -n /opt/alevin-fry/bin/alevin-fry-allowlist; \
    sh -n /opt/alevin-fry/bin/qcatch-gene-map; \
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
