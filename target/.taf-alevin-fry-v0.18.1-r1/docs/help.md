alevin-fry 0.18.1-r1

Purpose:
  Turn compatible RAD mappings into barcode permit lists, collated records,
  count matrices, equivalence-class results, or supported scATAC outputs.

Usage:
  taf-alevin-fry -- --help
  taf-alevin-fry alevin-fry --version
  taf-alevin-fry alevin-fry <subcommand> [options]
  Use the explicit "alevin-fry" command before upstream subcommands; names
  such as quant and collate are not standalone container executables.

Core RNA workflow:
  taf-alevin-fry alevin-fry generate-permit-list \
    -i af-map -d fw -o af-permit -k -t 8
  taf-alevin-fry alevin-fry collate \
    -i af-permit -r af-map -t 8 --memory-limit 2GiB --compress
  taf-alevin-fry alevin-fry quant \
    -i af-permit -m transcript-to-gene.tsv -o af-quant \
    -r cr-like-em -t 8 --use-mtx

Other tasks:
  taf-alevin-fry alevin-fry convert \
    -b queryname-grouped.bam -o af-map/map.rad -t 8 --filter_best
  taf-alevin-fry alevin-fry view -r af-map/map.rad -H
  taf-alevin-fry alevin-fry infer \
    -c af-quant/alevin/geqc_counts.mtx \
    -e af-quant/alevin/gene_eqclass.txt.gz -o af-infer -t 8 --use-mtx
  taf-alevin-fry alevin-fry atac generate-permit-list --help
  taf-alevin-fry alevin-fry atac sort --help

Required inputs:
  af-map/map.rad        Compatible piscem, Salmon alevin, or convert output.
  transcript-to-gene   Two columns for gene counts; three for USA mode.
  CR and UR tags        Required on SAM/BAM records used by convert.

Common controls:
  -k / -e N / -f N / -b FILE / -u FILE -m N
                        Choose one permit-list strategy.
  --memory-limit SIZE   Bound permit-list or collate working memory.
  --tmp-dir DIR         Put permit-list spill files on writable scratch.
  --small-thresh 0      Apply the requested quant resolution to every cell.
  --dump-eqclasses      Produce the matrix and archive consumed by infer.

Key outputs:
  permit_map.bin, permit_freq.bin, correction_plan.bin
  generate_permit_list.json, map.collated.rad[.sz], collate.json
  alevin/quants_mat.mtx, row/column labels, quant.json

Backends:
  Docker:    TAFFISH_CONTAINER_BACKEND=docker taf-alevin-fry alevin-fry --version
  Podman:    TAFFISH_CONTAINER_BACKEND=podman taf-alevin-fry alevin-fry --version
  Apptainer: TAFFISH_CONTAINER_BACKEND=apptainer taf-alevin-fry alevin-fry --version
  Keep inputs and outputs under the current working directory for ordinary
  wrapper use. For an external read-only data directory, add the matching bind:
  Docker:    TAFFISH_DOCKER_RUN_ARGS="-v /host/data:/data:ro" ...
  Podman:    TAFFISH_PODMAN_RUN_ARGS="-v /host/data:/data:ro" ...
  Apptainer: TAFFISH_APPTAINER_RUN_ARGS="--bind /host/data:/data:ro" ...

Immediate notes:
  The amd64 image needs an AVX2-capable x86-64-v3 CPU; Arm hosts should use
  the native arm64 image. This app is CPU-only and needs no database/model.
  collate writes into the permit-list directory. Keep correction_plan.bin and
  JSON/label files with their outputs. Alevin-fry does not map FASTQ or build
  references; a complete ATAC run needs mapper-compatible scATAC RAD input.

More help:
  taf-alevin-fry alevin-fry <subcommand> --help
  https://alevin-fry.readthedocs.io/en/latest/

Wrapper options:
  taf-alevin-fry --help       Show this TAFFISH help.
  taf-alevin-fry --version    Show the TAFFISH wrapper version.
  taf-alevin-fry --compile    Print the generated wrapper shell.
  taf-alevin-fry -- --help    Pass --help to the default upstream command.
