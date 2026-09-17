# alevin-fry

`alevin-fry` packages the official alevin-fry command-line program for
TAFFISH. Alevin-fry processes RAD mappings into barcode permit lists,
collated records and single-cell or single-nucleus count matrices. The same
binary also provides conversion, inspection, equivalence-class inference and
scATAC-seq RAD-processing interfaces.

## Package Identity

- Name: `alevin-fry`
- Command: `taf-alevin-fry`
- Kind: `tool`
- TAFFISH version: `0.18.3-r1`
- Container image: `ghcr.io/taffish/alevin-fry:0.18.3-r1`
- Upstream release: [`v0.18.3`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.18.3)
- Upstream commit: `ad05742d274230f9141b2eabeebd1c1b31692199`
- Runtime version: `alevin-fry 0.18.3`
- Native platforms: `linux/amd64`, `linux/arm64`
- TAFFISH app license: `Apache-2.0`
- Upstream license: `BSD-3-Clause`

The image uses the official architecture-specific GitHub release binary. The
release archives are pinned by SHA256:

| Platform | Release asset SHA256 |
| --- | --- |
| `linux/amd64` | `8f0d1d61643f8224b4267fffc106eee8639cedd7e66c5776d15ec6a25806d652` |
| `linux/arm64` | `e00184a2417706cfb4ff906bbf3b42a8e1beca4272f9983dbf8c8328176bf7b8` |

## Installation

```sh
taf update
taf install alevin-fry
```

For local validation before publication, use `taf install --from .` in this app directory.

## Scope

This app exposes the upstream `v0.18.3` command surface:

- `generate-permit-list` with knee, expected-cell, forced-cell, explicit and
  unfiltered barcode-list modes
- deterministic `unique` or abundance-weighted `frequency` cell-barcode
  correction across ordinary RNA filtering modes, multi-sample RNA and ATAC
- exact, unique or frequency sample-barcode correction for assays such as 10x
  Flex, with explicit neighbourhood and confidence controls
- a versioned `correction_plan.bin` handoff consumed by collation and ATAC
  sorting, with explicit compatibility fallback for older GPL output
- bounded, optionally compressed `collate` processing with `--memory-limit`
- per-chunk LZ4 collation, chunk-offset indexes and automatic parallel RAD reading
- `quant` with trivial, Cell Ranger-like, parsimony and EM resolutions
- explicit `--small-thresh` control and JSON provenance for the tiny-cell
  winner-take-all optimization
- standard gene-count and unspliced/spliced/ambiguous (USA) quantification
- bootstraps, summary statistics, quantification subsets and equivalence-class
  dumps
- separate, combined or both output layouts for multi-sample RAD input
- `infer` directly from the real-valued equivalence-class matrix written by
  `quant --dump-eqclasses`, with integer-matrix backward compatibility
- `convert` from queryname-grouped SAM/BAM with `CR` and `UR` tags to RAD
- `view` for RAD headers and records
- supported `atac generate-permit-list` and `atac sort` processing

This app does not map FASTQ reads, build a transcriptome index, choose a
chemistry, create a splici reference or perform downstream cell-level
statistics. Those are separate workflow stages. QCatch is a distinct
downstream package that produces an interactive HTML QC report; it is not part
of the alevin-fry executable or this CLI image.

## Container Contents

- `alevin-fry`: the official upstream Rust executable
- upstream README, changelog and BSD-3-Clause license
- release asset URL, checksum, commit and target-architecture provenance
- checksum-pinned Debian 12 slim runtime base
- deterministic offline smoke fixtures generated at runtime
- `alevin-fry-allowlist`: offline, checksum-verified preparation of user-acquired
  technology allowlists; no downloader or automatic license acceptance

The final image contains no compiler, Cargo cache, source tree, database,
reference, model or package-manager cache. The upstream executable has no helper
process or runtime network dependency.

## Command Mode

The names `quant`, `collate`, `infer` and the other operations are alevin-fry
subcommands, not separate executables. Use the explicit packaged command form:

```sh
taf-alevin-fry alevin-fry quant ...
taf-alevin-fry alevin-fry atac sort ...
```

Without the second `alevin-fry`, TAFFISH automatic command mode may interpret
the subcommand as another executable. Wrapper and upstream help are distinct:

```sh
taf-alevin-fry --help
taf-alevin-fry --version
taf-alevin-fry -- --help
taf-alevin-fry alevin-fry --version
taf-alevin-fry alevin-fry quant --help
```

Command mode re-parses a shell command. Retain literal inner quotes around
paths with spaces, for example
`taf-alevin-fry alevin-fry view -r "'mapped reads/map.rad'" -H`.
The current wrapper's read-only bind and spaced input/output paths are tested
with this syntax. Docker defaults may run as container root; choose an
ordinary-user policy when required: Docker `--user UID:GID`, Podman
`--userns keep-id --user UID:GID` in the corresponding `TAFFISH_*_RUN_ARGS`.
Apptainer runs under the calling user's site permissions.

## RNA Workflow

A typical RNA path starts from a mapper-produced directory containing
`map.rad`:

```sh
taf-alevin-fry alevin-fry generate-permit-list \
  -i af-map -d fw -o af-permit -k -t 8

taf-alevin-fry alevin-fry collate \
  -i af-permit -r af-map -t 8 --compress

taf-alevin-fry alevin-fry quant \
  -i af-permit -m transcript-to-gene.tsv -o af-quant \
  -r cr-like-em -t 8 --use-mtx
```

`collate` has no output-directory option; it writes its collated RAD and
`collate.json` into the permit-list directory. Use `--memory-limit 2GiB` (or
another explicit byte size) to bound its buffer budget; `--max-records` is a
hidden compatibility option rather than the recommended resource control.

Since 0.18.3, `--compress` (or `--compress lz4`) produces per-chunk LZ4
compression inside `map.collated.rad`; omitting it produces uncompressed RAD.
Both forms can have an adjacent `map.collated.rad.chunkidx`. Quantification
automatically uses the index for parallel reading; an absent, truncated or
stale index falls back to the single reader. Keep the RAD and its matching
index together. To explicitly select the single reader in any backend:

```sh
taf-alevin-fry env AF_RAD_READERS=1 alevin-fry quant \
  -i af-permit -m transcript-to-gene.tsv -o af-quant-serial \
  -r cr-like-em -t 8 --use-mtx
```

Older whole-file Snappy `map.collated.rad.sz` remains readable, but is not
seekable by the new parallel reader. Use a fresh permit directory rather
than mixing new `.rad` output and a stale `.rad.sz`: the legacy file takes
precedence when both exist. `--compress zstd` requires upstream's optional
`zstd` build feature, which the official binaries packaged here do not enable;
use LZ4 or uncompressed output. This app does not alter upstream build features.

To dump and then re-infer gene equivalence classes, first add
`--dump-eqclasses` to `quant`, then pass its outputs directly to `infer`:

```sh
taf-alevin-fry alevin-fry infer \
  -c af-quant/alevin/geqc_counts.mtx \
  -e af-quant/alevin/gene_eqclass.txt.gz \
  -o af-infer -t 8 --use-mtx
```

Version 0.17.0 accepts the `real` Matrix Market file written by `quant` and
also retains compatibility with older or third-party `integer` matrices. Keep
the row and column label files beside `geqc_counts.mtx`.

The transcript-to-gene map uses two columns for ordinary gene quantification:

```text
transcript_id<TAB>gene_id
```

USA mode uses the upstream three-column transcript map and a compatible
splici reference. Choose the orientation, permit-list strategy and resolution
from the assay and study design; the examples are not universal defaults.

Since 0.17.1, cells with fewer than 100 records use a fast Cell Ranger-like
winner-take-all path by default, independent of the requested `--resolution`.
The selected cell count and indices are recorded in `quant.json`. Pass
`--small-thresh 0` when every cell must use the requested resolution strategy.
The prefer-ambiguity splicing model always uses the general path.

### Producing RAD Input

Current upstream tutorials recommend `piscem`, usually orchestrated through
`simpleaf`, to create compatible RAD input. Legacy Salmon alevin RAD can also
be consumed when its format is compatible. Neither mapper is bundled here,
because indexing, chemistry geometry, mapping and reference construction are
independent scientific stages.

The `convert` subcommand is useful when compatible mappings already exist as
queryname-grouped SAM/BAM:

```sh
taf-alevin-fry alevin-fry convert \
  -b mappings.bam -o af-map/map.rad -t 8 --filter_best
```

Input records need cell-barcode `CR` and UMI `UR` tags. `--filter_best` uses
alignment scores where available. `convert` is not a FASTQ mapper.

## Multi-Barcode And Multi-Sample Data

The 0.18 series unifies cell and sample barcode correction. Supply sample
barcodes and select the desired policies during permit-list generation:

```sh
taf-alevin-fry alevin-fry generate-permit-list \
  -i af-map -d fw -o af-permit -k -t 8 \
  --sample-bc-list sample-barcodes.txt \
  --sample-names sample-names.tsv \
  --sample-bc-correction frequency \
  --sample-bc-neighborhood hamming-1 \
  --sample-bc-confidence 0.975 \
  --cell-bc-correction frequency \
  --cell-bc-neighborhood hamming-1 \
  --cell-bc-confidence 0.975 \
  --memory-limit 1GiB --tmp-dir af-correction-tmp
```

The `unique` policy accepts only observations with one canonical target.
`frequency` uses frozen exact counts and an exact confidence comparison.
Sample correction also supports `exact`, which is the default. The legacy
`--sample-correction-mode` and `--collation-mode` spellings remain accepted
but are hidden from normal help. Use
`quant --multi-sample-output separate|combined|both` as appropriate for the
RAD barcode layout, and consult the exact upstream tutorial before choosing
assay-specific policies.

## scATAC-seq

The supported `atac` command path provides permit-list generation and
coordinate-sorted, deduplicated BED output from compatible scATAC RAD files:

```sh
taf-alevin-fry alevin-fry atac generate-permit-list --help
taf-alevin-fry alevin-fry atac sort --help
```

A compatible scATAC `map.rad`, normally created by the appropriate `piscem`
mapping mode, is required. This image does not bundle piscem or an ATAC index.
Upstream v0.17.0 fixes defects in the older `atac collate` and
`atac deduplicate` implementations, but also hides both commands as
provisional and explicitly identifies `generate-permit-list` followed by
`sort` as the supported pipeline. This app follows that public boundary.

## Inputs And Outputs

| Item | Meaning |
| --- | --- |
| `map.rad` | Mapper or `convert` output consumed by permit-list generation |
| Barcode list | Optional known/whitelist barcodes, one per line |
| Sample barcode files | Optional multi-barcode whitelist and barcode-to-name TSV |
| Transcript-to-gene map | Two-column ordinary map or upstream-defined three-column USA map |
| `permit_map.bin`, `permit_freq.bin` | Compatibility map and corrected aggregate frequencies |
| `correction_plan.bin` | Versioned internal GPL-to-collate/ATAC correction handoff |
| `generate_permit_list.json` | Resolved correction policy and diagnostic counts |
| `map.collated.rad` | Uncompressed or per-chunk LZ4 collated records; older whole-file `.rad.sz` remains accepted as input |
| `map.collated.rad.chunkidx` | Optional matching chunk-offset index for parallel quantification |
| `quants_mat.mtx` | Cell-by-feature Matrix Market count matrix |
| `quants_mat_rows.txt` | Cell barcode labels |
| `quants_mat_cols.txt` | Gene or feature labels |
| `quant.json`, `collate.json` | Command, version and processing metadata |
| ATAC BED output | Coordinate-sorted, deduplicated fragments from `atac sort` |

Keep the JSON metadata and label files with each matrix. Use a fresh, writable
output directory for every run. Since 0.18.2, quantification streams matrix entries and
finalizes their headers only after successful processing. An interrupted or
failed run may leave partial outputs; it does not write new success metadata,
but a pre-existing `quant.json` is not a valid success signal for a rerun.
Check the process exit code and do not consume incomplete output.

`quant --num-bootstraps N` writes `bootstraps_mean.mtx` and
`bootstraps_var.mtx`, with the same cell/feature dimensions as the count
matrix. Full per-replicate MTX export is not implemented; without
`--summary-stat`, upstream computes replicates but still exports their
mean/variance and warns about this boundary. With `--summary-stat`, its
summary-computation convention is retained. Bootstrap analysis cannot be
combined with USA mode. Use `--small-thresh 0` when bootstrap results are
required for all cells: the tiny-cell shortcut does not compute bootstrap
samples. Zero variance is a valid header-only sparse matrix.

## Resources, Databases, And Platform

Native images are available for `linux/amd64` and `linux/arm64`. The official
x86_64 release asset is compiled by upstream for `x86-64-v3` with AVX2, so the
amd64 image requires an AVX2-capable CPU and can fail under emulators that do
not expose AVX2. Arm hosts should use the native arm64 image. Alevin-fry is
CPU-only; `--threads` controls parallel work. This release uses two threads
as its practical minimum and warns before raising smaller requests to two.
`generate-permit-list --memory-limit` bounds deferred sample-frequency
buffers (default 512 MiB), while `collate --memory-limit` bounds collation
buffers (default 2 GiB). Values below 256 MiB warn and use 256 MiB. GPL
`--tmp-dir` selects the Snappy-compressed spill directory. Compressed
collation trades CPU for disk space.

No model or reference bundle is embedded. Resource handling is classified by
the smallest independently reusable item, not by the presence of a downloader:

| Resource | Classification and handling |
| --- | --- |
| Sample RAD, filtered `--valid-bc` list, custom sample names/barcodes | Project-produced inputs; supply explicit paths and preserve their study provenance. |
| Transcript-to-gene map and mapper reference | Analysis-paired inputs; prepare together, do not silently substitute a global reference. |
| Technology-wide `--unfiltered-pl` allowlist, including 10x v2/v3 | Reusable resource; identify the technology, exact source release/member and data SHA256 separately from the app version. |
| Custom/vendor probe or sample-barcode panel | Assess the selected panel's own source and terms; an experiment-generated file is not equivalent to a standardized vendor panel. |

Normal processing is offline. The core accepts explicit files without
downloading missing resources. The optional preparation tool below handles
one user-selected, uniform-length, uncompressed A/C/G/T/N barcode list at a
time; it does not manage whole chemistry families, probe tables or reference
indexes, and never guesses chemistry or rewrites upstream arguments.

### Acquisition And Resource License

The alevin-fry BSD license does not license vendor barcode resources. The
official Cell Ranger [license at the audited source snapshot](https://github.com/10XGenomics/cellranger/blob/669395e208db7ce03354091e271d893074294d28/LICENSE)
limits use to the stated internal/10x-product conditions, requires notices and
disallows redistribution/sublicensing. This is not an assertion that all
automated downloads are prohibited. TAFFISH cannot establish a recipient's
product entitlement or expand a site's authorized-user scope, so it neither
bundles these vendor lists nor downloads them on the user's behalf.

Obtain an authorized copy through the [official Cell Ranger distribution](https://www.10xgenomics.com/support/software/cell-ranger/downloads)
or your site's licensed installation, select the technology-specific member,
and retain its applicable notice and exact source release/path. Do not infer
a resource license from a third-party mirror or from this app's Apache/BSD
licenses. If the member has separate terms, those terms must be reviewed too.
Record the selected file's approved SHA256; it is not the Cell Ranger release
number or the alevin-fry version. Decompress an authorized `.gz` copy with
`gzip -dc source.txt.gz > allowlist.txt` before import and record the hash of
the resulting plain text. No production vendor resource is included in smoke.

### Prepare Once, Reuse Read-Only

The helper only imports a local file after explicit `--rights-reviewed`:
this records the operator's review, not a grant or proof of legal permission.
It checks SHA256/format/space, copies the notice, records ID/source/size/scope,
uses a per-ID lock and same-filesystem staging, verifies its inventory, and
atomically exposes the completed member. Repeating the same complete import
is a no-op; changed, corrupt, incomplete or symlinked members fail closed.
There is no `--force`: use a new immutable ID and retain the old receipt.
Remote retry/resume/cache/parallel-download options are N/A to this offline
import path, not to the reusable-resource classification. Failed staging is
removed; a stale lock after an uncatchable process kill requires administrator
inspection before removal. No other user's lock is automatically broken.

Recommended roots (resource ID is a technology/source revision, not 0.18.3):

- Personal: `~/.local/share/taffish/resources/alevin-fry/<ID>/`
- Site: `/usr/local/share/taffish/resources/alevin-fry/<ID>/`
- Alternative site: `/opt/taffish/resources/alevin-fry/<ID>/`

Create a private parent directory before import. For site use, an administrator
creates the parent owned by the administrator and an existing authorized-user
group, with directory mode `0750`; only that administrator prepares members.
Run the helper with `--group-readable` for site imports: member directories
become `0750`, files `0640`, with the parent directory's group. Personal imports
use `0700`/`0600`. Vendor data is never made world-readable by the helper.
Only users covered by the applicable terms may belong to the sharing group.
If that scope is unavailable, use a private copy; do not expose a general
all-users site directory. An authorized root/admin prepares once; ordinary
authorized users reuse the shared read-only resource without root or another download.

Place `allowlist.txt` and its `LICENSE` in the current directory. Replace
`APPROVED_DATA_SHA256` and `SOURCE_RELEASE_AND_MEMBER` below with reviewed
values. Create the host parent first; bind paths must be absolute and free
of backend mount separators. For a personal root:

```sh
allowlist_root="$HOME/.local/share/taffish/resources/alevin-fry"
install -d -m 0700 "$allowlist_root"
export TAFFISH_CONTAINER_BACKEND=docker
export TAFFISH_DOCKER_RUN_ARGS="--user $(id -u):$(id -g) -v $allowlist_root:/resource-install"
taf-alevin-fry alevin-fry-allowlist prepare \
  --resource-root /resource-install --id technology-source-v1 \
  --file allowlist.txt --sha256 APPROVED_DATA_SHA256 --license-file LICENSE \
  --source urn:local:SOURCE_RELEASE_AND_MEMBER --rights-reviewed --dry-run
```

Remove `--dry-run` to prepare. For site imports the administrator substitutes
the site parent and adds `--group-readable`. The same helper arguments work
with these backend-specific setup choices:

```sh
export TAFFISH_CONTAINER_BACKEND=podman
export TAFFISH_PODMAN_RUN_ARGS="--userns keep-id --user $(id -u):$(id -g) -v $allowlist_root:/resource-install"
# Or on native Linux:
export TAFFISH_CONTAINER_BACKEND=apptainer
export TAFFISH_APPTAINER_RUN_ARGS="--bind $allowlist_root:/resource-install"
```

The writable `/resource-install` is used only with an actual explicit host
bind. The helper does not create or change image-root permissions. A member
contains `allowlist.txt`, `LICENSE`, `resource.tsv`, `SHA256SUMS` and `READY`.
Required extra space is one staged copy of data plus notice and at least
1 MiB reserve; exact byte/record counts are shown by `--dry-run` because no
production member is selected or downloaded by this app.

End the setup shell or unset the writable run arguments. For analysis, bind
the authorized prepared parent read-only and verify the selected member before use:

```sh
TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="-v /host/alevin-fry:/resources:ro" \
  taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="-v /host/alevin-fry:/resources:ro" \
  taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind /host/alevin-fry:/resources:ro" \
  taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
```

Use a real personal/site parent for `/host/alevin-fry`, restricted to the
operator's authorized resource scope. Keep the same read-only backend bind
and pass `--unfiltered-pl /resources/technology-source-v1/allowlist.txt` to
`alevin-fry generate-permit-list`. Optional `verify --sha256 HEX` also checks
against an independently recorded data digest; inventory verification alone
does not authenticate the supplier. The wrapper does not automatically
discover/mount vendor resources: explicit authorized-directory selection is
the deliberate access boundary. Override by changing the bind/path; disable
by removing it. Missing resources fail without a network fallback. Resolve
host symlinks to a backend-visible physical directory before binding.
External permissions such as Linux supplemental groups must be represented
by the engine's ordinary-user policy; being container root is not a grant
of permission to read or redistribute data.

| Capability | Docker | Podman | Apptainer | Boundary |
| --- | --- | --- | --- | --- |
| Ordinary working-directory I/O | `TAFFISH_CONTAINER_BACKEND=docker taf-alevin-fry ...` | `TAFFISH_CONTAINER_BACKEND=podman taf-alevin-fry ...` | `TAFFISH_CONTAINER_BACKEND=apptainer taf-alevin-fry ...` | The wrapper exposes the current working directory. |
| External read-only input | `TAFFISH_DOCKER_RUN_ARGS="-v /host/data:/data:ro"` | `TAFFISH_PODMAN_RUN_ARGS="-v /host/data:/data:ro"` | `TAFFISH_APPTAINER_RUN_ARGS="--bind /host/data:/data:ro"` | Site/run policy; change both paths to real absolute paths. |

The upstream crate provides one CPU command-line executable, with no GUI
extra, plugin, service entry point, GPU or device interface. The ecosystem
does include downstream graphical reporting: upstream links to
[alevinQC](https://github.com/csoneson/alevinQC) (R/Shiny, HTML and PDF,
primarily for Salmon alevin), and COMBINE-lab provides
[QCatch](https://github.com/COMBINE-lab/QCatch), which consumes alevin-fry
matrices/metadata or AnnData and performs additional QC before producing
interactive HTML. Neither is an executable dependency of quantification.
This CLI image does not provide or validate those report interfaces. QCatch
requires a separately versioned Python/scientific-computing environment and
its own input-mutation, resource and browser audit; use its documented
separate installation for downstream QC. No GUI-completeness claim is made
for the broader ecosystem. Simpleaf remains the separate TAFFISH workflow
and registry-management app.

## Upstream `v0.18.3` Changes And Behaviors

The tag-to-tag source comparison, rather than the bundled changelog (which
still ends at 0.18.2), identifies this release's changes:

- Multi-sample barcode-correction concurrency is bounded by the effective
  memory budget, sample histogram sizes, sample count and requested threads,
  replacing the previous hard cap of four sample workers.
- Collation writes a chunk-offset sidecar for seekable RAD output. Quantification
  uses parallel readers when a valid sidecar is present; `AF_RAD_READERS=1`
  selects the single-reader path. Default reader count is four.
- `--compress [CODEC]` selects per-chunk LZ4 by default. Optional zstd requires
  a separately compiled upstream feature and is not enabled in these official
  release binaries. Legacy whole-file Snappy input remains supported.
- The locked `libradicl` dependency advances to 0.19.1. No new external
  runtime helper, downloader, GUI, GPU or reference/model requirement is added.

Streaming matrices and their write-error handling from 0.18.2 are retained.
Upstream's production performance measurements are not packaging benchmarks
performed by this app.

- Barcode correction is deterministic across whitelist order, hash iteration,
  worker completion order and thread count. Cell policies are `unique` and
  `frequency`; sample policies are `exact`, `unique` and `frequency`.
- Cell and sample frequency confidence accepts decimal or exact fraction
  values. Neighbourhoods distinguish Hamming-1 from the historical
  substitution-or-shift-1 rule.
- GPL writes a versioned `correction_plan.bin`; current collation and ATAC
  sorting apply those compiled decisions directly. A missing plan activates an
  explicit older-output fallback, while a malformed or unsupported plan is an
  error.
- Ambiguous sample-frequency cases spill to bounded Snappy-compressed temporary
  runs controlled by `--memory-limit` and `--tmp-dir`.
- Single- and multi-barcode collation use bounded parallel engines.
  `--sample-correction-mode`, `--max-records` and `--collation-mode` remain
  accepted only as hidden compatibility spellings.
- Quantification reuses sparse scratch/equivalence-class state, corrects
  bootstrap and summary-stat handling, and release builds abort rather than
  unwind on panic.

Compatibility retained from 0.17.x includes direct real-matrix
`quant --dump-eqclasses` to `infer` processing, the explicit
`--small-thresh` tiny-cell control and its JSON provenance, and the supported
`atac generate-permit-list` then `atac sort` public surface.

## Testing

The independent offline smoke suite checks:

- exact release identity, commit provenance, architecture asset and dynamic
  library completeness
- top-level help plus all public RNA interfaces and the supported ATAC surface
- real SAM-to-RAD conversion and RAD record inspection
- permit-list generation, compressed collation and parsimony quantification
- uncompressed/LZ4 chunk offsets, 1/4-reader count equality, missing/truncated
  index fallback and the official disabled-zstd boundary
- frequency correction of a real one-mismatch barcode, exact correction
  diagnostics and the versioned correction-plan handoff
- Matrix Market labels, JSON metadata and non-empty equivalence-class dumps
- direct `quant --dump-eqclasses` to `infer` processing from a real matrix
- default and disabled tiny-cell resolution paths, including `quant.json`
  threshold, count and cell-index provenance
- positive `infer` processing from a deterministic integer matrix
- streamed sparse matrix dimensions, coordinate bounds, entry counts and labels
- deterministic one-gene bootstrap mean and zero-variance outputs, both with
  and without `--summary-stat`, and a USA matrix
- an invalid matrix destination causing nonzero exit and no new `quant.json`;
  an additional full-device late-write probe when `/dev/full` is exposed

The smoke confirms that provisional ATAC commands remain hidden from public
help. A full ATAC scientific run is not in the fast suite because it requires
mapper-specific ATAC RAD input; smoke fixtures validate packaging behavior,
not biological accuracy on production data.

When an upstream stage fails, the helper names its log-backed stage, preserves
the original exit status and prints only the final 200 log lines so Index
diagnostics remain useful and bounded.

This release retains the previously introduced offline allowlist helper and
adds independent chunk-codec/index regression coverage. The manifest contains
28 command-existence probes and 9 independent tests. Current 0.18.3 candidate
validation on 2026-09-14 passed the following checks; no older receipt substitutes
for this candidate's validation:

| Native environment | Exact direct smoke | Real generated wrapper |
| --- | --- | --- |
| Linux ARM64 Docker VM | 37 normal + 37 read-only | 44 |
| xjp Linux AMD64 Docker | 37 normal + 37 read-only | 44 |
| xjp Linux AMD64 Podman | 37 normal + 37 read-only | 44 |
| xjp Linux AMD64 Apptainer | 37 actual read-only SIF | 44 |

All 259 direct checks run independently with networking disabled. The 176
wrapper checks include ordinary-user execution, literal spaced/non-ASCII
arguments, actual read-only input binds, persistent allowlist import, checksum
and permission drift, lock/partial-state refusal and no corrupt overwrite.
An additional administrator-once synthetic-resource scenario passes 18
functional/permission checks across the three backends, plus 8 cleanup checks:
authorized ordinary users can reuse the resource but cannot write it, while
users outside the authorized group cannot read it. No host `sudo` or system
installation is used; administrator ownership is tested through a controlled
Docker bind of this task's synthetic files.

Both native images were built from the canonical Action's app-root context
using `docker/Dockerfile`. AMD64 Docker/Podman use identical OCI configuration
and layer identities; the actual SIF is derived from that OCI archive.
The platform and backend coverage axes are both closed. ARM64 Podman and
Apptainer are **not separately validated**; this thin CPU wrapper has no
architecture-specific backend, GPU, service or mount coupling that requires
those additional combinations. This does not claim every platform/backend
combination was tested.

Final uncompressed image sizes are 81,181,016 bytes (AMD64) and 103,342,170 bytes
(ARM64). The packaged executable/documents/helpers occupy about 6 MiB; most
space is the pinned Debian runtime. The final stage contains no build tools,
download archives or package-manager caches. Runtime libraries and their Debian
notices, and the upstream BSD notice, are retained. Build-time checks use stable
version/help/library and tiny conversion checks, not a pager, full rendered help,
browser or complete multi-threaded regression suite.

Production vendor resources, site licensing decisions, the full ATAC mapper
chain, multi-sample memory/performance scaling and biological accuracy are
outside packaging validation. Legacy whole-file Snappy compatibility is retained
by the reviewed upstream source; the new runtime regression suite exercises the
current uncompressed/LZ4 formats, not a production archive collection. These are
local candidate results, not evidence of a published image or completed Index run.

## Documentation, License, And Citation

- [Upstream repository](https://github.com/COMBINE-lab/alevin-fry)
- [Alevin-fry documentation](https://alevin-fry.readthedocs.io/en/latest/)
- [Official tutorials](https://combine-lab.github.io/alevin-fry-tutorials/)
- [Release `v0.18.3`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.18.3)

TAFFISH packaging code and documentation use Apache-2.0. The bundled upstream
binary and notices remain BSD-3-Clause. The upgraded libradicl dependency's
original BSD notice is reproduced in the accompanying
[THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES), from its fixed source commit;
this does not grant rights to vendor barcode resources.

Please cite:

> He D, Zakeri M, Sarkar H, Soneson C, Srivastava A, Patro R. Alevin-fry
> unlocks rapid, accurate and memory-frugal quantification of single-cell
> RNA-seq data. Nature Methods. 2022;19:316-322.
> doi:10.1038/s41592-022-01408-3. PMID:35277707.
