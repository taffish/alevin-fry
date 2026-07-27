alevin-fry 0.16.2-r1

Purpose:
  Process compatible RAD mappings into barcode permit lists, collated records,
  sc/snRNA-seq count matrices, equivalence-class results, or scATAC outputs.

Usage:
  taf-alevin-fry -- --help
  taf-alevin-fry alevin-fry --version
  taf-alevin-fry alevin-fry <subcommand> [options]

Core RNA workflow:
  taf-alevin-fry alevin-fry generate-permit-list \
    -i af-map -d fw -o af-permit -k -t 8
  taf-alevin-fry alevin-fry collate \
    -i af-permit -r af-map -t 8 --compress
  taf-alevin-fry alevin-fry quant \
    -i af-permit -m transcript-to-gene.tsv -o af-quant \
    -r cr-like-em -t 8 --use-mtx

Main subcommands:
  generate-permit-list  Call/correct cell barcodes from map.rad.
  collate               Group corrected RAD records by cell barcode.
  quant                 Produce gene or USA count matrices.
  infer                 Infer counts from integer equivalence-class input.
  convert               Convert queryname-grouped tagged SAM/BAM to RAD.
  view                  Print RAD headers and records.
  atac                   Process compatible scATAC-seq RAD files.

Important command form:
  These names are alevin-fry subcommands, not container executables.
  Use "taf-alevin-fry alevin-fry quant ...", not
  "taf-alevin-fry quant ...".

Permit-list modes:
  -k                    Knee-distance calling.
  -e N                  Expected-cell threshold.
  -f N                  Keep the N most frequent barcodes.
  -b FILE               Explicit valid barcode list.
  -u FILE -m N          Unfiltered list with minimum read count.
  --sample-bc-list      Enable multi-barcode/sample correction.

Common inputs:
  af-map/map.rad        Compatible piscem, legacy Salmon, or convert output.
  transcript-to-gene   Two columns for ordinary counts; three for USA mode.
  CR and UR tags        Required cell barcode and UMI tags for convert input.

Key outputs:
  permit_map.bin and permit_freq.bin
  map.collated.rad or map.collated.rad.sz
  alevin/quants_mat.mtx
  alevin/quants_mat_rows.txt and quants_mat_cols.txt
  quant.json and collate.json

scATAC interfaces:
  taf-alevin-fry alevin-fry atac generate-permit-list --help
  taf-alevin-fry alevin-fry atac sort --help
  taf-alevin-fry alevin-fry atac collate --help
  taf-alevin-fry alevin-fry atac deduplicate --help

Platform and resources:
  Native linux/amd64 and linux/arm64 images; CPU only; no database or model.
  The official amd64 binary requires x86-64-v3/AVX2; use arm64 natively on Arm.
  Use --threads for CPU parallelism and collate --max-records to bound memory.
  Files outside the backend-visible working directory need a bind mount.

Boundaries:
  This image does not map FASTQ, build an index, select chemistry, construct a
  splici reference, bundle piscem/simpleaf, or run downstream cell statistics.
  A full ATAC run requires a mapper-compatible scATAC map.rad.

Upstream 0.16.2 notes:
  Some filtered permit-list modes can emit a misleading barcode-length-zero
  warning; inspect JSON and counts before treating that message as failure.
  quant --dump-eqclasses writes a real-typed Matrix Market header, while infer
  requires integer input. Preserve the original and review a header-normalized
  copy before direct infer use. See README.md for the exact boundary.

Detailed documentation:
  https://github.com/taffish/alevin-fry
  https://alevin-fry.readthedocs.io/en/latest/
  https://combine-lab.github.io/alevin-fry-tutorials/

Wrapper options:
  taf-alevin-fry --help       Show this TAFFISH help.
  taf-alevin-fry --version    Show TAFFISH wrapper version.
  taf-alevin-fry --compile    Print the generated wrapper shell.
  taf-alevin-fry -- --help    Pass --help to the default upstream command.
License/citation: TAFFISH Apache-2.0; upstream BSD-3-Clause; He et al.,
  Nature Methods 19, 316-322 (2022); DOI 10.1038/s41592-022-01408-3; PMID 35277707.
