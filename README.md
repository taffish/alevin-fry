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
- TAFFISH version: `0.17.1-r1`
- Container image: `ghcr.io/taffish/alevin-fry:0.17.1-r1`
- Upstream release: [`v0.17.1`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.17.1)
- Upstream commit: `9c82c0ba8432ceea18d25089833d82cc5950fb59`
- Runtime version: `alevin-fry 0.17.1`
- Native platforms: `linux/amd64`, `linux/arm64`
- TAFFISH app license: `Apache-2.0`
- Upstream license: `BSD-3-Clause`

The image uses the official architecture-specific GitHub release binary. The
release archives are pinned by SHA256:

| Platform | Release asset SHA256 |
| --- | --- |
| `linux/amd64` | `9f0ecdc66ba8d3aac7a9b79d092a10c57341209f5aef345965eb23692e73b56e` |
| `linux/arm64` | `3562605999b8c650860bdd8bf85e19aef71fbac1332e8a02a6e3729069e78d70` |

## Installation

```sh
taf update
taf install alevin-fry
```

For local validation before publication, use `taf install --from .` in this app directory.

## Scope

This app exposes the upstream `v0.17.1` command surface:

- `generate-permit-list` with knee, expected-cell, forced-cell, explicit and
  unfiltered barcode-list modes
- multi-barcode/sample correction for assays such as 10x Flex
- `collate` with compressed output and `two-round` or `fast` collation
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
statistics. Those are separate workflow stages.

## Container Contents

- `alevin-fry`: the official upstream Rust executable
- upstream README, changelog and BSD-3-Clause license
- release asset URL, checksum, commit and target-architecture provenance
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
`collate.json` into the permit-list directory.

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

In 0.17.1, cells with fewer than 100 records use a fast Cell Ranger-like
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

Version 0.16.2 introduced sample/library barcode correction and output controls. Supply
sample barcodes during permit-list generation:

```sh
taf-alevin-fry alevin-fry generate-permit-list \
  -i af-map -d fw -o af-permit -k -t 8 \
  --sample-bc-list sample-barcodes.txt \
  --sample-names sample-names.tsv \
  --sample-correction-mode 1-edit \
  --sample-bc-ori forward
```

Use `collate --collation-mode two-round|fast` and
`quant --multi-sample-output separate|combined|both` as appropriate for the
RAD barcode layout. Consult the exact upstream tutorial for the assay before
selecting these options.

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
| `permit_map.bin`, `permit_freq.bin` | Barcode correction and frequency state |
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
CPU-only; `--threads` controls parallel work. `collate --max-records` bounds
the records retained in memory per batch, and compressed collation trades CPU
for disk space.

There is no embedded or downloadable database, model or reference package.
All references, transcript maps, barcode lists and RAD files are explicit
project inputs. Normal processing is offline. Paths under the working
directory are visible through ordinary TAFFISH execution; paths elsewhere on
the host need a backend-visible bind mount.

## Upstream `v0.17.1` Changes And Behaviors

- `--small-thresh` is public and effective again. Its default is 100, matching
  the optimization that older versions actually applied; zero disables the
  tiny-cell fast path.
- `quant.json` now records `num_tiny_cell_resolved` and
  `tiny_cell_resolved_cell_numbers`, so a run reveals which cells bypassed the
  requested resolution strategy. The prefer-ambiguity splicing model bypasses
  the fast path entirely.
- Releases before 0.17.1 parsed `--small-thresh` but dropped it, while a
  hard-coded threshold of 100 silently selected Cell Ranger-like semantics for
  small cells. Re-run affected analyses with 0.17.1 when this distinction
  matters scientifically.

Compatibility notes retained from 0.17.0:

- Some filtered permit-list modes may log that the
  provided permit list has barcode length zero even when no external list was
  provided. The outputs use the RAD `cblen` value; inspect the resulting JSON
  and barcode counts rather than treating this message alone as a wrapper
  failure.
- `quant --dump-eqclasses` writes a `real` Matrix Market file. Version 0.17.0
  fixes direct chaining by letting `infer` read that file first and fall back
  to the older `integer` representation. The smoke suite tests both forms.
- `infer` also expects `quants_mat_rows.txt` and `quants_mat_cols.txt` beside
  the count matrix and writes its three matrix/label outputs directly into the
  selected output directory.
- The release adopts libradicl 0.17 and noodles 0.115, moves gzip handling to
  the pure-Rust zlib-rs backend, and fixes ATAC collation chunk accounting and
  a producer-start hang in provisional deduplication.

## Testing

The independent offline smoke suite checks:

- exact release identity, commit provenance, architecture asset and dynamic
  library completeness
- top-level help plus all public RNA interfaces and the supported ATAC surface
- real SAM-to-RAD conversion and RAD record inspection
- permit-list generation, compressed collation and parsimony quantification
- Matrix Market labels, JSON metadata and non-empty equivalence-class dumps
- direct `quant --dump-eqclasses` to `infer` processing from a real matrix
- default and disabled tiny-cell resolution paths, including `quant.json`
  threshold, count and cell-index provenance
- positive `infer` processing from a deterministic integer matrix

The smoke confirms that provisional ATAC commands remain hidden from public
help. A full ATAC scientific run is not in the fast suite because it requires
mapper-specific ATAC RAD input; smoke fixtures validate packaging behavior,
not biological accuracy on production data.

## Documentation, License, And Citation

- [Upstream repository](https://github.com/COMBINE-lab/alevin-fry)
- [Alevin-fry documentation](https://alevin-fry.readthedocs.io/en/latest/)
- [Official tutorials](https://combine-lab.github.io/alevin-fry-tutorials/)
- [Release `v0.17.1`](https://github.com/COMBINE-lab/alevin-fry/releases/tag/v0.17.1)

TAFFISH packaging code and documentation use Apache-2.0. The bundled upstream
binary and notices remain BSD-3-Clause.

Please cite:

> He D, Zakeri M, Sarkar H, Soneson C, Srivastava A, Patro R. Alevin-fry
> unlocks rapid, accurate and memory-frugal quantification of single-cell
> RNA-seq data. Nature Methods. 2022;19:316-322.
> doi:10.1038/s41592-022-01408-3. PMID:35277707.
