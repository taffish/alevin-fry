alevin-fry 0.18.3-r1

Purpose:
  Process compatible RAD mappings into permit lists, collated records and counts.

Usage:
  taf-alevin-fry -- --help
  taf-alevin-fry alevin-fry --version
  taf-alevin-fry alevin-fry <subcommand> [options]
  Always include "alevin-fry" before an upstream subcommand. For spaced paths:
  taf-alevin-fry alevin-fry view -r "'mapped reads/map.rad'" -H

Core RNA workflow:
  taf-alevin-fry alevin-fry generate-permit-list -i af-map -d fw -o af-permit -k -t 8
  taf-alevin-fry alevin-fry collate \
    -i af-permit -r af-map -t 8 --memory-limit 2GiB --compress
  taf-alevin-fry alevin-fry quant -i af-permit -m transcript-to-gene.tsv \
    -o af-quant -r cr-like-em -t 8 --use-mtx
  Other commands: convert, view, infer, atac generate-permit-list, atac sort.
  Run taf-alevin-fry alevin-fry <subcommand> --help for their arguments.

Inputs and controls:
  map.rad: compatible mapper output; convert accepts grouped SAM/BAM with CR/UR tags.
  Transcript map: two columns for ordinary counts; three for compatible USA input.
  -k / -e N / -f N / -b FILE / -u FILE -m N: choose one permit-list strategy.
  --memory-limit SIZE and --tmp-dir DIR: bound memory and choose writable GPL scratch.
  --dump-eqclasses: emit matrix/archive inputs for infer; keep the label files.
  collate writes into the permit-list directory, not a separate output directory.
  --compress [lz4]: per-chunk LZ4 in .rad; zstd is unavailable in official binaries.
  To force one RAD reader: taf-alevin-fry env AF_RAD_READERS=1 alevin-fry quant ...

Key outputs:
  permit_map.bin, permit_freq.bin, correction_plan.bin, generate_permit_list.json
  map.collated.rad and optional .chunkidx, collate.json, alevin/quants_mat.mtx and labels
  quant.json: success metadata. Older whole-file .rad.sz input remains readable.

Prepare an authorized reusable allowlist:
  Technology-wide allowlists are not sample-filtered -b lists. No vendor data is bundled.
  Obtain the correct authorized plain-text list and its notice from the supplier/site.
  Record its approved SHA256 and source revision. Do not grant access beyond the license.
  Create a private host parent /host/resources first; keep allowlist.txt and LICENSE in CWD.
  Choose docker, podman or apptainer using TAFFISH_CONTAINER_BACKEND, e.g.:
  export TAFFISH_CONTAINER_BACKEND=docker
  Set the matching writable setup arguments (replace /host/resources):
  export TAFFISH_DOCKER_RUN_ARGS="--user $(id -u):$(id -g) -v /host/resources:/resource-install"
  export TAFFISH_PODMAN_RUN_ARGS="--userns keep-id --user $(id -u):$(id -g) -v /host/resources:/resource-install"
  export TAFFISH_APPTAINER_RUN_ARGS="--bind /host/resources:/resource-install"
  taf-alevin-fry alevin-fry-allowlist prepare --resource-root /resource-install \
    --id technology-source-v1 --file allowlist.txt --sha256 APPROVED_DATA_SHA256 \
    --license-file LICENSE --source urn:local:SOURCE_REVISION --rights-reviewed --dry-run
  Remove --dry-run to import. Personal permissions are private; an authorized site admin
  adds --group-readable only when the parent group contains authorized users (0750/0640).
  Identical imports skip; corrupt/conflicting IDs fail. Never overwrite an old member.

Use shared inputs read-only:
  End the setup shell or replace its writable arguments with a read-only bind below.
  /host/resources is the authorized parent containing technology-source-v1/.
  TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="-v /host/resources:/resources:ro" \
    taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
  TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="-v /host/resources:/resources:ro" \
    taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
  TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind /host/resources:/resources:ro" \
    taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
  Keep that same backend/bind for generate-permit-list and replace -k with:
    -u /resources/technology-source-v1/allowlist.txt -m MIN_READS
  No automatic discovery/download: change the explicit bind/path to select a different
  prepared resource; remove it to disable access. Site users need read permission, not root.
  For other external input directories use the same backend read-only bind syntax.
  Ordinary wrapper input/output under the working directory needs no additional bind.

Immediate notes:
  The amd64 image requires x86-64-v3/AVX2; Arm hosts should use native arm64.
  CPU-only; no model is required. FASTQ mapping/reference construction are separate steps.
  Full ATAC processing requires mapper-compatible scATAC RAD input.
  Use fresh permit and quant directories; never mix new .rad with an old .rad.sz.
  Failed streaming may leave partial matrices.
  Check the exit code; an old quant.json is not a valid success signal for a rerun.
  Bootstraps export mean/variance MTX, not individual replicate matrices; --summary-stat
  requests summary computation. USA mode cannot use bootstraps. Add --small-thresh 0
  to use the requested resolution/bootstraps for cells below 100 records.

More help:
  taf-alevin-fry alevin-fry-allowlist --help
  https://github.com/taffish/alevin-fry#resources-databases-and-platform
  https://alevin-fry.readthedocs.io/en/latest/

Wrapper options:
  --help: this help. --version: wrapper version. --compile: generated wrapper shell.
  Use taf-alevin-fry -- --help for upstream help.
