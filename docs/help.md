alevin-fry 0.18.0-r1

Purpose:
  Process RAD mappings into permit lists, collated records, count matrices,
  equivalence-class results, or scATAC outputs.

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
  infer                 Infer counts from real or integer eq-class input.
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
  --cell-bc-correction  Select unique or frequency correction.
  --memory-limit SIZE   Bound GPL or collate working buffers.

Common inputs:
  af-map/map.rad        Compatible piscem, legacy Salmon, or convert output.
  transcript-to-gene   Two columns for ordinary counts; three for USA mode.
  CR and UR tags        Required cell barcode and UMI tags for convert input.

Key outputs:
  permit_map.bin, permit_freq.bin, correction_plan.bin, and GPL JSON diagnostics
  map.collated.rad or map.collated.rad.sz
  alevin/quants_mat.mtx
  alevin/quants_mat_rows.txt and quants_mat_cols.txt
  quant.json and collate.json

Equivalence-class inference:
  Pass geqc_counts.mtx and gene_eqclass.txt.gz from quant --dump-eqclasses to
  infer; 0.17.0+ accepts quant's real matrix and older integer matrices.

Supported scATAC: atac generate-permit-list and atac sort; append --help for each.
Platform and resources:
  Native linux/amd64 and linux/arm64 images; CPU only; no database or model.
  The official amd64 binary requires x86-64-v3/AVX2; use arm64 natively on Arm.
  Minimum two threads; use --memory-limit for buffers and GPL --tmp-dir for spills.
  Files outside the backend-visible working directory need a bind mount.

Boundaries:
  This image does not map FASTQ, build an index, select chemistry, construct a
  splici reference, bundle piscem/simpleaf, or run downstream cell statistics.
  QCatch interactive HTML QC is a separate downstream package, not this image.
  A full ATAC run requires a mapper-compatible scATAC map.rad.
Upstream version notes:
  0.18.0 adds deterministic unique/frequency correction and correction_plan.bin.
  Keep the plan with GPL output; confidence, neighborhood, and memory are explicit.
  Legacy sample-correction-mode, max-records, and collation-mode remain hidden.
  Quant output passes directly to infer; --small-thresh 0 disables fast-path.
  Provisional atac collate/deduplicate are hidden; use permit-list then sort.

Detailed documentation:
  https://alevin-fry.readthedocs.io/en/latest/
  https://combine-lab.github.io/alevin-fry-tutorials/

Wrapper options:
  taf-alevin-fry --help       Show this TAFFISH help.
  taf-alevin-fry --version    Show TAFFISH wrapper version.
  taf-alevin-fry --compile    Print the generated wrapper shell.
  taf-alevin-fry -- --help    Pass --help to the default upstream command.
License/citation: TAFFISH Apache-2.0; upstream BSD-3-Clause; He et al.,
  Nature Methods 19, 316-322 (2022); DOI 10.1038/s41592-022-01408-3; PMID 35277707.
