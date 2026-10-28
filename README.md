# alevin-fry

`alevin-fry` packages the official alevin-fry command-line program for
TAFFISH. Alevin-fry processes RAD mappings into barcode permit lists,
collated records and single-cell or single-nucleus count matrices. The same
binary also provides conversion, inspection, equivalence-class inference and
scATAC-seq RAD-processing interfaces. The image additionally includes the
independent upstream QCatch 0.2.14 QC/report application and an offline HTML packer.

## Package Identity

- Name: `alevin-fry`
- Command: `taf-alevin-fry`
- Kind: `tool`
- TAFFISH version: `0.19.0-r1`
- Container image: `ghcr.io/taffish/alevin-fry:0.19.0-r1`
- Upstream release: [`v0.19.0`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.19.0)
- Upstream commit: `1117219ec9cbd070293df0a329a37d9fc44be44a`
- Runtime version: `alevin-fry 0.19.0`
- Native platforms: `linux/amd64`, `linux/arm64`
- TAFFISH app license: `Apache-2.0`
- Upstream license: `BSD-3-Clause`

The image uses the official architecture-specific GitHub release binary. The
release archives are pinned by SHA256:

| Platform | Release asset SHA256 |
| --- | --- |
| `linux/amd64` | `fb3e5ea646f4582bf550a91f25c2d5446a26b40caca2fe04a96780760c11d52c` |
| `linux/arm64` | `b17b48f6fb14f1d35f3c3be2edecc18153422face40f586c65234df05e15c2b3` |

## Installation

```sh
taf update
taf install alevin-fry
```

For local validation before publication, use `taf install --from .` in this app directory.

## Scope

This app exposes the upstream `v0.19.0` command surface:

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
- one combined matrix for multi-sample RAD input, with `<sample>_<barcode>` rows
- RAD v1 and role-annotated RAD v2 input
- explicit `quant-probe` for probe-set references, optional probe matrix and
  `--dump-molecules` Parquet output
- `infer` directly from the real-valued equivalence-class matrix written by
  `quant --dump-eqclasses`, with integer-matrix backward compatibility
- `convert` from queryname-grouped SAM/BAM with `CR` and `UR` tags to RAD
- `view` for RAD headers and records
- supported `atac generate-permit-list` and `atac sort` processing

This app does not map FASTQ reads, build a transcriptome index, choose a
chemistry or create a splici reference. QCatch is a separate downstream analysis
stage, not an alevin-fry subcommand. Its native cell calling, optional doublet
detection and dimensionality reduction are unchanged; their scientific choices
remain the user's responsibility.

## Container Contents

- `alevin-fry`: the official upstream Rust executable
- upstream README, changelog and BSD-3-Clause license
- release asset URL, checksum, commit and target-architecture provenance
- checksum-pinned Python 3.11 / Debian Bookworm runtime base
- QCatch 0.2.14 with architecture-specific hash-locked wheels; no host Python needed
- `qcatch`: local-input guard plus the unmodified QCatch console program
- `qcatch-offline`: explicit standalone copy of a native QCatch HTML report
- `qcatch-gene-map`: rights-reviewed, checksum-verified local mapping import
- deterministic offline smoke fixtures generated at runtime
- `alevin-fry-allowlist`: offline, checksum-verified preparation of user-acquired
  technology allowlists; no downloader or automatic license acceptance

The final image contains no compiler, Cargo cache, build tree, database,
reference, model or package-manager cache. QCatch's Python sources and complete
source archive are retained for its license obligations. The alevin-fry executable
has no helper process or runtime network dependency.

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
but are hidden from normal help. `quant --multi-sample-output` is deprecated, hidden and ignored: output is
always one combined matrix. Sample names from `--sample-names` are now applied.
Consult the exact upstream tutorial before choosing assay-specific policies.

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

Recommended roots (resource ID is a technology/source revision, not 0.19.0):

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

The Rust executable has no GUI, GPU, plugin or service entry point.
[alevinQC](https://github.com/csoneson/alevinQC) remains a separate R/Shiny
application, primarily for Salmon alevin. The maintainer explicitly selected
the independent [QCatch 0.2.14](https://github.com/COMBINE-lab/QCatch/releases/tag/v0.2.14)
companion for this image instead. Simpleaf remains a separate workflow app.

### QCatch Native And Offline Reports

```sh
taf-alevin-fry qcatch --input af-quant --output qc-results \
  --gene_id2name_file genes.tsv --chemistry 10X_3p_v3 --export_summary_table
taf-alevin-fry qcatch-offline --input qc-results/QCatch_report.html \
  --output qc-results/QCatch_offline.html
```

Use your actual chemistry or `--n_partitions`; the wrapper never selects one.
For an explicitly supplied cell set, use the upstream `--valid_cell_list`.
`--skip_umap_tsne` omits embeddings for faster QC; `--remove_doublets` and
`--visualize_doublets` are upstream options. Keep full original AF output
including `featureDump.txt`, matrix/labels and metadata, or a compatible H5AD.
The native report, modified/filtered H5AD and optional summary CSV are QCatch
outputs. Analysis may leave partial results after failure; exit zero alone is
not proof that a report exists (the upstream no-valid-cells branch returns zero).

Automatic cell calling also needs an appropriate population of background
barcodes. The upstream 0.2.14 caller rejects a tiny, nearly uniform high-count
fixture with `Invalid selection of 0-count barcodes!`; this is retained rather
than patched or silently replaced by a cell set. Use `--valid_cell_list` only
when you have independently selected that set. A compatible original H5AD is
accepted; do not assume QCatch's already-annotated output H5AD is a clean input
for another run with the same gene-map columns. Preserve the original input.

TAFFISH requires an explicit local two-column headerless gene-ID/name TSV and
a separate `--output`, even if an H5AD already contains symbols. It refuses
implicit registry lookup and in-place input rewriting, without changing the
upstream analysis algorithm. No live network fallback is exposed by the normal
`qcatch` entry. Per-invocation writable caches are private and removed on exit;
read-only OCI/SIF runs do not write installed Python packages. `qcatch --help`
prints this packaging policy before the upstream option text.

The original `QCatch_report.html` uses online Plotly/Bootstrap/D3/highlight
assets. `qcatch-offline` preserves that file and every embedded plot payload,
inlines a fixed browser dependency set, and writes a **new** standalone HTML.
It fails on unknown required assets, bad bundled checksums, or any existing
output (including a dangling symlink). Plotly comes from the installed 6.0.0
wheel, matching the generator, rather than the template's redundant older
2.20.0 loader. The template also references an absent `css/index.css`, which
is shipped by neither the 0.2.14 wheel/sdist nor the generated output; this
known dangling link is explicitly omitted and reported, not replaced by an
invented stylesheet. Other unknown dependencies still fail. The source HTML SHA256 is embedded as provenance. External
documentation links still need internet; no server, port, SSH tunnel or GPU is
needed to open the resulting report in a browser. The offline copy visibly
labels its presentation-only adaptation: fixed-size native plots scroll inside
their containers, and the sidebar/columns stack on narrow screens. Plot scales,
payloads and analysis results are unchanged; the original report is not rewritten.

All three backends use the same installed commands. Working-directory inputs
need no extra bind; for an external read-only project/reference directory use
the Docker/Podman/Apptainer bind table above. For spaces retain literal inner
quotes, e.g. `--input "'native quant'" --output "'QC results'"`.

### QCatch Mapping Resources

A project-generated gene map is an explicit analysis input, not a database.
A reusable reference map may be prepared once and shared with authorized users.
The official QCatch-resources catalog currently lists CellRanger-derived
members at external Box URLs without payload hashes, sizes or member license
fields. Its repository BSD notice is not treated as a grant for those external
datasets. No such payload is bundled or automatically downloaded. Obtain an
authorized fixed copy and its applicable notice from your reference provider;
record the independently approved SHA256 and source revision.

For reusable mappings, use the same private/site setup and read-only bind
pattern as allowlists, but choose a separate parent such as
`~/.local/share/taffish/resources/alevin-fry/gene-maps` or the corresponding
`/usr/local/share` / `/opt/taffish` authorized site directory:

```sh
taf-alevin-fry qcatch-gene-map prepare --resource-root /resource-install \
  --id reference-revision --file genes.tsv --sha256 APPROVED_DATA_SHA256 \
  --license-file LICENSE --source urn:local:REFERENCE_REVISION --rights-reviewed --dry-run
taf-alevin-fry qcatch-gene-map verify --resource-root /resources --id reference-revision
```

Remove `--dry-run` for import; add `--group-readable` only for an authorized
site group. The same immutable inventory, complete validation, staged atomic
promotion, space check, fail-closed and recovery rules apply as for allowlists.
The prepared data file is `reference-revision/gene-map.tsv`; pass that exact
read-only path to `--gene_id2name_file`. No auto-discovery/auto-selection is
performed across references. Override/disable by changing/removing the explicit
bind. Input licenses may forbid broader sharing; preparation does not grant it.

### QCatch Source And Licenses

QCatch tag `v0.2.14` resolves to `d6ce3eb9bf3b74b20dadc2b6a204d1d0c894f4c1`.
The unmodified PyPI wheel SHA256 is
`f09abd730edae019c62b6d5193c519ea30740d17e0065dd5d1ff0a9e0b943785`;
the complete source archive SHA256 is
`0dbb13452436bbcc69903da95206eebbfa272a516e0f83e002c96c519d031e38`.
It is preserved under `/opt/alevin-fry/share/sources/`. Its root BSD-3-Clause
notice explicitly assigns `find_retained_cells/` to Affero GPL v2, with MIT
attributions. That transitional license permits distribution under GNU AGPLv3;
the original notices, transition text and AGPLv3 text are retained under
`share/licenses/qcatch`; installed Python sources remain in `/opt/qcatch`, and the
full source archive remains under `share/sources`. This app's Apache license does
not relicense those components.
Frontend asset manifests and MIT/BSD notices remain under
`share/qcatch-assets`; Python wheel notices remain in their distributions.
See `share/doc/qcatch/packages.txt` and `requirements.lock` for the actual
runtime closure. The official sdist's old uv.lock was used only as dependency
constraints; the two new wheel locks pin QCatch 0.2.14 and the resolved closure.

## Upstream `v0.19.0` Changes And Behaviors

- RAD v2 (piscem 0.24+) and legacy RAD v1 are accepted. Tag roles can identify
  barcode/UMI fields independently of their names.
- Re-run `generate-permit-list` for 0.18.x results; collation/ATAC sorting
  reject a different major.minor version. Re-run provisional ATAC collate and
  deduplicate together: old whole-file Snappy ATAC collations are not compatible.
- `quant-probe` resolves molecules per probe and sums probes into gene counts.
  Use it only with a probe-set reference, not an ordinary transcriptome.
  `quant` remains the earlier gene-level path; results are intentionally not
  interchangeable. `--probe-mtx` adds the probe matrix; USA maps, gene-parsimony
  variants and bootstrapping are not supported by this new interface.
- `quant --dump-molecules` writes `alevin/molecules.parquet`. The input needs
  the `ulen` file tag, including when barcode/UMI roles are otherwise present.
  It adds compute/memory/output cost; no external Parquet writer is required.
- `--umi-edit-dist 1` enables cr-like/cr-like-em Hamming-1 UMI correction,
  disables the tiny-cell shortcut and is refused for USA/prefer-ambiguity.
- Resolution names accept mixed case; missing-subset inference and worker-error
  hangs are fixed. Invalid RAD/USA combinations fail with useful diagnostics.
- `--sample-names` is applied, while `--multi-sample-output` remains ignored
  and is now hidden. Pre-0.15 multi-sample collations must be regenerated.
- The official build retains no optional zstd feature. libradicl is now 0.21.0;
  Arrow/Parquet 60.0.0 supplies the new LZ4-compressed molecule output.

Use a fresh output directory and keep the exit status and JSON provenance.
Upstream performance and biological evaluations are not packaging benchmarks
or scientific validations performed by this app.

Example for an already-collated, appropriate probe-set input:

```sh
taf-alevin-fry alevin-fry quant-probe -i probe-permit -m probes-to-genes.tsv \
  -o probe-counts -r cr-like-em -t 8 --probe-mtx --dump-molecules
```

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

The 0.19.0 successor also checks role-only RAD v2 conversion/inspection,
permit generation, collation, probe/gene matrix dimensions, finalized Parquet
output, mixed-case correction and incompatible old permit/USA rejection.

Current-source native builds and real generated-wrapper validation pass on
ARM64 Docker/Podman and xjp native AMD64 Docker/Podman/Apptainer. There are
414 successful independent exact commands (33 exist, one combined existence
probe and 12 tests in nine normal/read-only/SIF runs), 645 CLI/resource wrapper
checks, 85 QCatch wrapper checks, 25 encoding/recovery checks and five runtime
source/permission audits. The QCatch checks include 55 signal/output/promotion
subcases. Administrator-once site sharing has 26 behavioral checks plus two
isolated ownership setup/cleanup actions. No old 0.18.3 receipt is counted.

| Native image | Uncompressed size | Config identity |
| --- | --- | --- |
| AMD64 | 1,220,145,816 bytes | `7a398c89f19817ea213a6e497821a4b4e4d4db23ece8b1e5289c59e740948955` |
| ARM64 | 1,251,665,891 bytes | `65492a51576cf17e0a009d2688e9b1134e90190c506a65796e4015b74276d3de` |

The AMD64 SIF, generated from the same OCI, has SHA256
`704b541428d9c1b7abce0da71afe32497c29ec644f6acb52e6a74d7787c1dbc2`.
The larger image is explained by the explicitly included scientific Python/QC
environment (about 1.2 GB under `/opt/qcatch`), not a build cache or bundled
reference collection. Python source/license obligations are retained. Native
QCatch Python file hashes match the wheel RECORD, and `pip check` passes.

The final offline report was actually opened at desktop and 390-pixel widths:
navigation, long logs, help, retained/all-cell switching, zoom/reset, point
tooltips and PNG download pass. Original plot payloads and native HTML remain
unchanged. ARM64 Apptainer is not separately validated. One earlier ARM64
Podman client timeout and a stopped VM were retained as failures; the final
same-image re-run passes after the authorized Podman restart. Docker's earlier
default-HOME stall was also retained and the final default-HOME wrapper retry
passes. These are not upstream algorithm fixes or relaxed smoke assertions.

Production vendor resources, site licensing decisions, full mapper pipelines,
multi-sample memory/performance scaling and biological accuracy are outside
packaging validation. No full production database/model is downloaded.

## Documentation, License, And Citation

- [Upstream repository](https://github.com/COMBINE-lab/alevin-fry)
- [Alevin-fry documentation](https://alevin-fry.readthedocs.io/en/latest/)
- [Official tutorials](https://combine-lab.github.io/alevin-fry-tutorials/)
- [Release `v0.19.0`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.19.0)

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
