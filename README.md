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
- TAFFISH version: `0.18.1-r1`
- Container image: `ghcr.io/taffish/alevin-fry:0.18.1-r1`
- Upstream release: [`v0.18.1`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.18.1)
- Upstream commit: `afa67499c59503d0996a0fbf8cf85cc3c45999a6`
- Runtime version: `alevin-fry 0.18.1`
- Native platforms: `linux/amd64`, `linux/arm64`
- TAFFISH app license: `Apache-2.0`
- Upstream license: `BSD-3-Clause`

The image uses the official architecture-specific GitHub release binary. The
release archives are pinned by SHA256:

| Platform | Release asset SHA256 |
| --- | --- |
| `linux/amd64` | `8dc94acdc3f5e20723dd5c11460c4bf3066d0f7cc8c8cd54460c08cb24d2e5c4` |
| `linux/arm64` | `bfb25069cfdf46f1a53703ca3fc767afdbaffc7b155d08d536ca60b42544e4b6` |

## Installation

```sh
taf update
taf install alevin-fry
```

For local validation before publication, use `taf install --from .` in this app directory.

## Scope

This app exposes the upstream `v0.18.1` command surface:

- `generate-permit-list` with knee, expected-cell, forced-cell, explicit and
  unfiltered barcode-list modes
- deterministic `unique` or abundance-weighted `frequency` cell-barcode
  correction across ordinary RNA filtering modes, multi-sample RNA and ATAC
- exact, unique or frequency sample-barcode correction for assays such as 10x
  Flex, with explicit neighbourhood and confidence controls
- a versioned `correction_plan.bin` handoff consumed by collation and ATAC
  sorting, with explicit compatibility fallback for older GPL output
- bounded, optionally compressed `collate` processing with `--memory-limit`
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

The final image contains no compiler, Cargo cache, source tree, database,
reference, model or package-manager cache. The executable has no helper
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
| `map.collated.rad[.sz]` | Cell-barcode-collated RAD records |
| `quants_mat.mtx` | Cell-by-feature Matrix Market count matrix |
| `quants_mat_rows.txt` | Cell barcode labels |
| `quants_mat_cols.txt` | Gene or feature labels |
| `quant.json`, `collate.json` | Command, version and processing metadata |
| ATAC BED output | Coordinate-sorted, deduplicated fragments from `atac sort` |

Keep the JSON metadata and label files with each matrix. Output directories
must be writable and should not already contain unrelated results.

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

There is no embedded or downloadable database, model or reference package.
All references, transcript maps, barcode lists and RAD files are explicit
project inputs. Normal processing is offline. Paths under the working
directory are visible through ordinary TAFFISH execution; paths elsewhere on
the host need a backend-visible bind mount.

The shared-resource installer gate is therefore N/A for this release: the
program does not acquire or manage external persistent assets.
Reference sequences, transcript maps, assay barcode lists and RAD files are
study inputs whose identity belongs to the analysis rather than a global
alevin-fry installation. Keep reusable authorized inputs in a site-controlled
read-only directory and expose only the required path.

| Capability | Docker | Podman | Apptainer | Boundary |
| --- | --- | --- | --- | --- |
| Ordinary working-directory I/O | `TAFFISH_CONTAINER_BACKEND=docker taf-alevin-fry ...` | `TAFFISH_CONTAINER_BACKEND=podman taf-alevin-fry ...` | `TAFFISH_CONTAINER_BACKEND=apptainer taf-alevin-fry ...` | The wrapper exposes the current working directory. |
| External read-only input | `TAFFISH_DOCKER_RUN_ARGS="-v /host/data:/data:ro"` | `TAFFISH_PODMAN_RUN_ARGS="-v /host/data:/data:ro"` | `TAFFISH_APPTAINER_RUN_ARGS="--bind /host/data:/data:ro"` | Site/run policy; change both paths to real absolute paths. |

The upstream crate provides one CPU command-line executable. Its package,
dependency, source-entry-point and companion-project audit found no official
optional GUI, browser service, GPU or device interface to add here. Simpleaf
is the official higher-level workflow companion and remains a separate
TAFFISH app; downstream QC/report packages remain separate runtimes as well.

## Upstream `v0.18.1` Changes And Behaviors

Version 0.18.1 is an output-neutral performance update over 0.18.0. It reuses
per-worker scratch buffers in Cell Ranger-like quantification, reads RAD input
through a 4 MiB buffer, uses the fixed-u64 map for collation byte accounting,
and buffers JSON metadata reads. It also updates `libradicl` to 0.18.1. The
public CLI, output formats, resource model and supported platforms are
unchanged.

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
- frequency correction of a real one-mismatch barcode, exact correction
  diagnostics and the versioned correction-plan handoff
- Matrix Market labels, JSON metadata and non-empty equivalence-class dumps
- direct `quant --dump-eqclasses` to `infer` processing from a real matrix
- default and disabled tiny-cell resolution paths, including `quant.json`
  threshold, count and cell-index provenance
- positive `infer` processing from a deterministic integer matrix

The smoke confirms that provisional ATAC commands remain hidden from public
help. A full ATAC scientific run is not in the fast suite because it requires
mapper-specific ATAC RAD input; smoke fixtures validate packaging behavior,
not biological accuracy on production data.

When an upstream stage fails, the helper names its log-backed stage, preserves
the original exit status and prints only the final 200 log lines so Index
diagnostics remain useful and bounded.

Both declared native architectures passed the complete Docker and Podman
functional matrices. The actual read-only Apptainer SIF, exact smoke matrix,
wrapper and bind semantics were validated natively on `linux/amd64`. Native
`linux/arm64` Apptainer was not separately exercised: the wrapper has no
backend-specific runtime arguments or architecture-coupled mount behavior,
and the arm64 OCI runtime paths already passed independently. This low-risk
unverified combination does not reduce the Apptainer backend result; the
post-publication Index Action remains the feedback path for a combination-
specific failure, which would be fixed in a new immutable release.

## Documentation, License, And Citation

- [Upstream repository](https://github.com/COMBINE-lab/alevin-fry)
- [Alevin-fry documentation](https://alevin-fry.readthedocs.io/en/latest/)
- [Official tutorials](https://combine-lab.github.io/alevin-fry-tutorials/)
- [Release `v0.18.1`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.18.1)

TAFFISH packaging code and documentation use Apache-2.0. The bundled upstream
binary and notices remain BSD-3-Clause.

Please cite:

> He D, Zakeri M, Sarkar H, Soneson C, Srivastava A, Patro R. Alevin-fry
> unlocks rapid, accurate and memory-frugal quantification of single-cell
> RNA-seq data. Nature Methods. 2022;19:316-322.
> doi:10.1038/s41592-022-01408-3. PMID:35277707.
