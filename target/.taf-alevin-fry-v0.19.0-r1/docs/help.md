alevin-fry 0.19.0-r1 (with QCatch 0.2.14)

Purpose:
  Turn compatible RAD mappings into counts; optionally make QCatch HTML QC reports.

Usage:
  taf-alevin-fry -- --help
  taf-alevin-fry alevin-fry --version
  taf-alevin-fry alevin-fry <subcommand> [options]
  Include "alevin-fry" before its subcommand. Spaced paths need literal inner quotes:
  taf-alevin-fry alevin-fry view -r "'mapped reads/map.rad'" -H

Core RNA workflow:
  taf-alevin-fry alevin-fry generate-permit-list -i af-map -d fw -o af-permit -k -t 8
  taf-alevin-fry alevin-fry collate \
    -i af-permit -r af-map -t 8 --memory-limit 2GiB --compress
  taf-alevin-fry alevin-fry quant -i af-permit -m transcript-to-gene.tsv \
    -o af-quant -r cr-like-em -t 8 --use-mtx
  Probe-set input only: use quant-probe; --probe-mtx adds probe counts.
  --dump-molecules writes alevin/molecules.parquet; input needs the ulen file tag.
  Keep quant.json, featureDump.txt, matrix/labels and metadata together.
  collate writes into af-permit. Failed runs can leave partial output; check exit status.

QCatch local QC and browser report:
  taf-alevin-fry qcatch --input af-quant --output qc-results \
    --gene_id2name_file genes.tsv --chemistry 10X_3p_v3 --export_summary_table
  taf-alevin-fry qcatch-offline --input qc-results/QCatch_report.html \
    --output qc-results/QCatch_offline.html
  Use your actual chemistry or --n_partitions, not an arbitrary example value.
  A local headerless gene-ID/name TSV and separate output are required; no auto-download.
  --valid_cell_list supplies your own cell set; --skip_umap_tsne omits embeddings.
  Native HTML uses online assets. Open the offline copy in a browser; no server/port.
  Offline packing refuses existing outputs. The native report/data stay unchanged.
  No retained cells can mean no report even when upstream exits zero; inspect outputs.
  taf-alevin-fry qcatch --help

Prepare authorized reusable inputs:
  No vendor allowlist or reference map is bundled. Obtain an authorized local copy,
  approved SHA256 and applicable LICENSE; sharing must stay within its terms.
  Create a private host parent /host/resources; keep the source file and notice in CWD.
  Choose TAFFISH_CONTAINER_BACKEND=docker, podman or apptainer, then its setup arguments:
  export TAFFISH_DOCKER_RUN_ARGS="--user $(id -u):$(id -g) -v /host/resources:/resource-install"
  export TAFFISH_PODMAN_RUN_ARGS="--userns keep-id --user $(id -u):$(id -g) -v /host/resources:/resource-install"
  export TAFFISH_APPTAINER_RUN_ARGS="--bind /host/resources:/resource-install"
  taf-alevin-fry alevin-fry-allowlist prepare --resource-root /resource-install \
    --id technology-source-v1 --file allowlist.txt --sha256 APPROVED_DATA_SHA256 \
    --license-file LICENSE --source urn:local:SOURCE_REVISION --rights-reviewed --dry-run
  For a reusable gene map use qcatch-gene-map instead, --file genes.tsv and a reference ID.
  Remove --dry-run to import. An authorized admin adds --group-readable for site sharing.
  Personal copies stay private; only authorized group members may reuse a site copy.
  Identical imports skip; incomplete/corrupt/conflicting IDs fail. Use a new ID, not overwrite.

Use shared inputs read-only:
  End the setup shell or replace writable arguments with the matching read-only bind:
  TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="-v /host/resources:/resources:ro" \
    taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
  TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="-v /host/resources:/resources:ro" \
    taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
  TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind /host/resources:/resources:ro" \
    taf-alevin-fry alevin-fry-allowlist verify --resource-root /resources --id technology-source-v1
  Keep that same backend/bind for generate-permit-list; replace -k with:
    -u /resources/technology-source-v1/allowlist.txt -m MIN_READS
  For a prepared gene map, verify with qcatch-gene-map and its reference ID, then use:
    qcatch --gene_id2name_file /resources/reference-id/gene-map.tsv ...
  Select/override a resource using its explicit bind/path; remove the bind to disable it.
  No automatic discovery. Resolve host symlinks to physical paths before binding.
  Ordinary working-directory I/O needs no extra bind; external inputs use the same syntax.

Immediate notes:
  amd64 requires x86-64-v3/AVX2; Arm hosts should use native arm64. CPU-only; no model.
  RAD v1/v2: compatible mapper output; convert accepts grouped SAM/BAM with CR/UR tags.
  Transcript maps use two columns for ordinary counts, three for compatible USA input.
  Choose one permit strategy: -k / -e N / -f N / -b FILE / -u FILE -m N.
  Re-run generate-permit-list for 0.18.x output; use fresh permit and quant directories.
  Re-run old ATAC collate/deduplicate together; do not reuse its legacy .rad.sz.
  Multi-sample output is always combined; --multi-sample-output is ignored.
  --compress uses per-chunk LZ4; zstd is unavailable in the official binaries.
  --dump-eqclasses emits infer inputs; keep their label files.
  Bootstraps export mean/variance MTX; USA cannot use bootstraps. --small-thresh 0
  applies the requested resolution/bootstraps even to cells below 100 records.

More help:
  taf-alevin-fry alevin-fry-allowlist --help
  taf-alevin-fry qcatch-gene-map --help
  https://github.com/taffish/alevin-fry#resources-databases-and-platform
  https://alevin-fry.readthedocs.io/en/latest/

Wrapper options:
  --help: this help. --version: wrapper version. --compile: generated wrapper shell.
