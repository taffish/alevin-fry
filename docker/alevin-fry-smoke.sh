#!/bin/sh
set -eu

AF=/opt/alevin-fry/bin/alevin-fry
EXPECTED_VERSION=0.18.2
MODE=${1:-}
TMP_ROOT=${2:-/tmp}

mkdir -p "$TMP_ROOT"
SESSION=$(mktemp -d "${TMP_ROOT%/}/taf-alevin-fry.XXXXXX")
trap 'rm -rf "$SESSION"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
TMP_ROOT=$SESSION

fail() {
    printf 'alevin-fry smoke: %s\n' "$*" >&2
    exit 1
}

run_logged() {
    log_file=$1
    shift
    set +e
    "$@" >"$log_file" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        printf 'alevin-fry smoke: stage=%s exit=%s\n' "$log_file" "$status" >&2
        tail -n 200 "$log_file" >&2 || true
        return "$status"
    fi
}

identity_check() {
    version_output=$($AF --version 2>&1)
    [ "$version_output" = "alevin-fry ${EXPECTED_VERSION}" ] || \
        fail "unexpected version: ${version_output}"
    test -s /opt/alevin-fry/share/licenses/alevin-fry/LICENSE
    test -s /opt/alevin-fry/share/doc/alevin-fry/README.md
    test -s /opt/alevin-fry/share/doc/alevin-fry/CHANGELOG.md
    grep -Fx "upstream_version=${EXPECTED_VERSION}" \
        /opt/alevin-fry/share/doc/alevin-fry/source.txt >/dev/null
    grep -Fx "upstream_commit=86dd6957aeb002725173bd257bf45ad034129a67" \
        /opt/alevin-fry/share/doc/alevin-fry/source.txt >/dev/null
    grep -E '^target_arch=(amd64|arm64)$' \
        /opt/alevin-fry/share/doc/alevin-fry/source.txt >/dev/null
    ldd_output=$(ldd "$AF" 2>&1)
    printf '%s\n' "$ldd_output" | grep -F "libc.so.6" >/dev/null
    if printf '%s\n' "$ldd_output" | grep -F "not found" >/dev/null; then
        printf '%s\n' "$ldd_output" >&2
        fail "missing dynamic library"
    fi
}

check_help() {
    marker=$1
    shift
    "$AF" "$@" --help >"$help_file" 2>&1
    grep -F -- "$marker" "$help_file" >/dev/null
}

quick_interfaces_check() {
    help_file="${TMP_ROOT%/}/taf-alevin-fry-quick-help-$$.txt"
    check_help "Process RAD files from the command line"
    check_help "--cell-bc-correction" generate-permit-list
    check_help "--memory-limit" collate
    check_help "--multi-sample-output" quant
    check_help "--small-thresh" quant
    check_help "subcommand for processing scATAC-seq RAD files" atac
    rm -f "$help_file"
}

interfaces_check() {
    help_file="${TMP_ROOT%/}/taf-alevin-fry-help-$$.txt"
    check_help "Process RAD files from the command line"
    check_help "--sample-bc-list" generate-permit-list
    check_help "--sample-bc-correction" generate-permit-list
    check_help "--cell-bc-correction" generate-permit-list
    check_help "--cell-bc-neighborhood" generate-permit-list
    check_help "--cell-bc-confidence" generate-permit-list
    check_help "--memory-limit" generate-permit-list
    check_help "--tmp-dir" generate-permit-list
    check_help "--memory-limit" collate
    check_help "--multi-sample-output" quant
    check_help "--small-thresh" quant
    check_help "parsimony-gene-em" quant
    check_help "--count-mat" infer
    check_help "--filter_best" convert
    check_help "--header" view
    check_help "generate-permit-list" atac
    check_help "--permit-bc-ori" atac generate-permit-list
    check_help "--cell-bc-correction" atac generate-permit-list
    check_help "--cell-bc-confidence" atac generate-permit-list
    "$AF" atac --help >"$help_file" 2>&1
    grep -F "generate-permit-list" "$help_file" >/dev/null
    grep -F "sort" "$help_file" >/dev/null
    if grep -F "collate" "$help_file" >/dev/null || \
       grep -F "deduplicate" "$help_file" >/dev/null; then
        fail "provisional ATAC subcommands unexpectedly visible in public help"
    fi
    "$AF" collate --help >"$help_file" 2>&1
    if grep -F -- "--max-records" "$help_file" >/dev/null || \
       grep -F -- "--collation-mode" "$help_file" >/dev/null; then
        fail "deprecated collation controls unexpectedly visible in public help"
    fi
    rm -f "$help_file"
}

tiny_cell_check() {
    work="${TMP_ROOT%/}/taf-alevin-fry-tiny-$$"
    mkdir -p "$work/map"
    make_small_sam "$work/reads.sam"
    run_logged "$work/convert.log" \
        "$AF" convert -b "$work/reads.sam" -o "$work/map/map.rad" -t 2
    printf 'AAAAAAAAAAAAAAAA\n' >"$work/valid-barcodes.txt"
    run_logged "$work/permit.log" \
        "$AF" generate-permit-list \
            -i "$work/map" -d fw -o "$work/permit" \
            -u "$work/valid-barcodes.txt" -m 1 -t 2
    run_logged "$work/collate.log" \
        "$AF" collate -i "$work/permit" -r "$work/map" \
            -t 2 --memory-limit 256MiB --compress
    printf 'tx1\tgeneA\ntx2\tgeneB\n' >"$work/t2g.tsv"

    run_logged "$work/quant-default.log" \
        "$AF" quant -i "$work/permit" -m "$work/t2g.tsv" \
            -o "$work/quant-default" -r parsimony-em -t 2 --use-mtx
    test -s "$work/quant-default/quant.json"
    default_json=$(tr -d '[:space:]' <"$work/quant-default/quant.json")
    printf '%s\n' "$default_json" | \
        grep -F '"num_tiny_cell_resolved":1' >/dev/null
    printf '%s\n' "$default_json" | \
        grep -F '"tiny_cell_resolved_cell_numbers":[0]' >/dev/null
    printf '%s\n' "$default_json" | \
        grep -F '"small_thresh":100' >/dev/null

    run_logged "$work/quant-disabled.log" \
        "$AF" quant -i "$work/permit" -m "$work/t2g.tsv" \
            -o "$work/quant-disabled" -r parsimony-em -t 2 \
            --small-thresh 0 --use-mtx
    test -s "$work/quant-disabled/quant.json"
    disabled_json=$(tr -d '[:space:]' <"$work/quant-disabled/quant.json")
    printf '%s\n' "$disabled_json" | \
        grep -F '"num_tiny_cell_resolved":0' >/dev/null
    printf '%s\n' "$disabled_json" | \
        grep -F '"tiny_cell_resolved_cell_numbers":[]' >/dev/null
    printf '%s\n' "$disabled_json" | \
        grep -F '"small_thresh":0' >/dev/null
    rm -rf "$work"
}

make_small_sam() {
    sam_file=$1
    cat >"$sam_file" <<'EOF'
@HD	VN:1.6	SO:queryname
@SQ	SN:tx1	LN:100
@SQ	SN:tx2	LN:100
r1	0	tx1	1	60	20M	*	0	0	ACGTACGTACGTACGTACGT	IIIIIIIIIIIIIIIIIIII	CR:Z:AAAAAAAAAAAAAAAA	UR:Z:CCCCCCCCCCCC
r2	0	tx1	5	60	20M	*	0	0	CGTACGTACGTACGTACGTA	IIIIIIIIIIIIIIIIIIII	CR:Z:AAAAAAAAAAAAAAAA	UR:Z:GGGGGGGGGGGG
r3	0	tx2	1	60	20M	*	0	0	TTTTCCCCAAAAGGGGTTTT	IIIIIIIIIIIIIIIIIIII	CR:Z:AAAAAAAAAAAAAAAA	UR:Z:TTTTTTTTTTTT
r4	0	tx2	5	60	20M	*	0	0	CCCCAAAAGGGGTTTTCCCC	IIIIIIIIIIIIIIIIIIII	CR:Z:AAAAAAAAAAAAAAAA	UR:Z:AAAAAAAAAAAA
r5	0	tx1	10	60	20M	*	0	0	AAAACCCCGGGGTTTTAAAA	IIIIIIIIIIIIIIIIIIII	CR:Z:AAAAAAAAAAAAAAAA	UR:Z:ACACACACACAC
r5	256	tx2	10	50	20M	*	0	0	AAAACCCCGGGGTTTTAAAA	IIIIIIIIIIIIIIIIIIII	CR:Z:AAAAAAAAAAAAAAAA	UR:Z:ACACACACACAC
EOF
}

make_large_sam() {
    sam_file=$1
    make_small_sam "$sam_file"
    i=6
    while [ "$i" -le 110 ]; do
        printf 'r%s\t0\ttx1\t20\t60\t20M\t*\t0\t0\tACGTACGTACGTACGTACGT\tIIIIIIIIIIIIIIIIIIII\tCR:Z:AAAAAAAAAAAAAAAA\tUR:Z:AGAGAGAGAGAG\n' \
            "$i" >>"$sam_file"
        i=$((i + 1))
    done
    printf 'r111\t0\ttx2\t25\t60\t20M\t*\t0\t0\tTTTTGGGGCCCCAAAATTTT\tIIIIIIIIIIIIIIIIIIII\tCR:Z:AAAAAAAAAAAAAAAC\tUR:Z:TGTGTGTGTGTG\n' \
        >>"$sam_file"
}

rad_check() {
    work="${TMP_ROOT%/}/taf-alevin-fry-rad-$$"
    mkdir -p "$work/map"
    make_small_sam "$work/reads.sam"
    run_logged "$work/convert.log" \
        "$AF" convert -b "$work/reads.sam" -o "$work/map/map.rad" -t 2
    test -s "$work/map/map.rad"
    "$AF" view -r "$work/map/map.rad" -H >"$work/view.tsv" 2>"$work/view.log"
    grep -Fx '0:tx1' "$work/view.tsv" >/dev/null
    grep -Fx '1:tx2' "$work/view.tsv" >/dev/null
    grep -F 'CB:AAAAAAAAAAAAAAAA' "$work/view.tsv" >/dev/null
    grep -F 'UMI:ACACACACACAC' "$work/view.tsv" >/dev/null
    rm -rf "$work"
}

rna_check() {
    work="${TMP_ROOT%/}/taf-alevin-fry-rna-$$"
    mkdir -p "$work/map"
    make_large_sam "$work/reads.sam"
    run_logged "$work/convert.log" \
        "$AF" convert -b "$work/reads.sam" -o "$work/map/map.rad" -t 2
    printf 'AAAAAAAAAAAAAAAA\n' >"$work/valid-barcodes.txt"
    run_logged "$work/permit.log" \
        "$AF" generate-permit-list \
            -i "$work/map" -d fw -o "$work/permit" \
            -u "$work/valid-barcodes.txt" -m 1 -t 2 \
            --cell-bc-correction frequency \
            --cell-bc-neighborhood hamming-1 \
            --cell-bc-confidence 3/4 \
            --memory-limit 256MiB --tmp-dir "$work/spool"
    test -s "$work/permit/permit_map.bin"
    test -s "$work/permit/permit_freq.bin"
    test -s "$work/permit/correction_plan.bin"
    test -s "$work/permit/generate_permit_list.json"
    gpl_json=$(tr -d '[:space:]' <"$work/permit/generate_permit_list.json")
    printf '%s\n' "$gpl_json" | grep -F '"cell_bc_correction":"frequency"' >/dev/null
    printf '%s\n' "$gpl_json" | grep -F '"resolved_cell_bc_neighborhood":"hamming-1"' >/dev/null
    printf '%s\n' "$gpl_json" | grep -F '"corrected_distinct":1' >/dev/null
    printf '%s\n' "$gpl_json" | grep -F '"corrected_reads":1' >/dev/null
    run_logged "$work/collate.log" \
        "$AF" collate -i "$work/permit" -r "$work/map" \
            -t 2 --memory-limit 256MiB --compress
    test -s "$work/permit/map.collated.rad.sz"
    test -s "$work/permit/collate.json"
    printf 'tx1\tgeneA\ntx2\tgeneB\n' >"$work/t2g.tsv"
    run_logged "$work/quant.log" \
        "$AF" quant -i "$work/permit" -m "$work/t2g.tsv" \
            -o "$work/quant" -r parsimony -t 2 \
            --dump-eqclasses --use-mtx
    test -s "$work/quant/alevin/quants_mat.mtx"
    test -s "$work/quant/alevin/quants_mat_rows.txt"
    test -s "$work/quant/alevin/quants_mat_cols.txt"
    test -s "$work/quant/alevin/geqc_counts.mtx"
    test -s "$work/quant/alevin/gene_eqclass.txt.gz"
    test -s "$work/quant/quant.json"
    grep -Fx 'AAAAAAAAAAAAAAAA' "$work/quant/alevin/quants_mat_rows.txt" >/dev/null
    grep -Fx 'geneA' "$work/quant/alevin/quants_mat_cols.txt" >/dev/null
    grep -Fx 'geneB' "$work/quant/alevin/quants_mat_cols.txt" >/dev/null
    grep -F 'matrix coordinate real general' "$work/quant/alevin/geqc_counts.mtx" >/dev/null
    grep -F '1 3 3' "$work/quant/alevin/geqc_counts.mtx" >/dev/null
    grep -F '"version_str": "0.18.2"' "$work/quant/quant.json" >/dev/null
    run_logged "$work/infer-from-quant.log" \
        "$AF" infer -c "$work/quant/alevin/geqc_counts.mtx" \
            -e "$work/quant/alevin/gene_eqclass.txt.gz" \
            -o "$work/infer-from-quant" -t 2 --use-mtx
    test -s "$work/infer-from-quant/quants_mat.mtx"
    test -s "$work/infer-from-quant/quants_mat_rows.txt"
    test -s "$work/infer-from-quant/quants_mat_cols.txt"
    grep -Fx 'AAAAAAAAAAAAAAAA' \
        "$work/infer-from-quant/quants_mat_rows.txt" >/dev/null
    grep -Fx 'geneA' "$work/infer-from-quant/quants_mat_cols.txt" >/dev/null
    grep -Fx 'geneB' "$work/infer-from-quant/quants_mat_cols.txt" >/dev/null
    rm -rf "$work"
}

infer_check() {
    work="${TMP_ROOT%/}/taf-alevin-fry-infer-$$"
    mkdir -p "$work/input"
    cat >"$work/input/geqc_counts.mtx" <<'EOF'
%%MatrixMarket matrix coordinate integer general
%
1 2 2
1 1 2
1 2 1
EOF
    printf 'AAAAAAAAAAAAAAAA\n' >"$work/input/quants_mat_rows.txt"
    printf 'geneA\ngeneB\n' >"$work/input/quants_mat_cols.txt"
    printf '2\n2\n0\t0\n1\t1\n' | gzip -n -c >"$work/input/gene_eqclass.txt.gz"
    run_logged "$work/infer.log" \
        "$AF" infer -c "$work/input/geqc_counts.mtx" \
            -e "$work/input/gene_eqclass.txt.gz" \
            -o "$work/output" -t 2 --use-mtx
    test -s "$work/output/quants_mat.mtx"
    test -s "$work/output/quants_mat_rows.txt"
    test -s "$work/output/quants_mat_cols.txt"
    grep -Fx 'AAAAAAAAAAAAAAAA' "$work/output/quants_mat_rows.txt" >/dev/null
    grep -Fx 'geneA' "$work/output/quants_mat_cols.txt" >/dev/null
    grep -Fx 'geneB' "$work/output/quants_mat_cols.txt" >/dev/null
    grep -F '1 2 2' "$work/output/quants_mat.mtx" >/dev/null
    rm -rf "$work"
}

check_matrix() {
    matrix=$1
    rows=$2
    cols=$3
    awk -v rows="$rows" -v cols="$cols" '
        /^%/ {next}
        !header {if (NF!=3 || $1!=rows || $2!=cols || $3<0) exit 1;
                 expected=$3; header=1; next}
        {if (NF!=3 || $1<1 || $1>rows || $2<1 || $2>cols ||
             $1!=int($1) || $2!=int($2) ||
             $3 !~ /^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/) exit 1;
         key=$1 SUBSEP $2; if (seen[key]++) exit 1; entries++}
        END {if (!header || entries!=expected) exit 1}
    ' "$matrix" || fail "invalid streamed matrix: $matrix"
}

streaming_check() {
    work="$TMP_ROOT/streaming"
    mkdir -p "$work/map"
    make_small_sam "$work/reads.sam"
    run_logged "$work/convert.log" "$AF" convert \
        -b "$work/reads.sam" -o "$work/map/map.rad" -t 2
    printf 'AAAAAAAAAAAAAAAA\n' >"$work/barcodes.txt"
    run_logged "$work/permit.log" "$AF" generate-permit-list \
        -i "$work/map" -d fw -o "$work/permit" -u "$work/barcodes.txt" -m 1 -t 2
    run_logged "$work/collate.log" "$AF" collate \
        -i "$work/permit" -r "$work/map" -t 2 --memory-limit 256MiB --compress
    printf 'tx1\tgeneA\ntx2\tgeneA\n' >"$work/t2g.tsv"
    for bootstrap_mode in summary replicates; do
        if [ "$bootstrap_mode" = summary ]; then set -- --summary-stat; else set --; fi
        out="$work/$bootstrap_mode"
        run_logged "$out.log" "$AF" quant -i "$work/permit" -m "$work/t2g.tsv" \
            -o "$out" -r cr-like-em -t 2 --use-mtx --small-thresh 0 --num-bootstraps 3 "$@"
        for name in quants_mat bootstraps_mean bootstraps_var; do
            check_matrix "$out/alevin/$name.mtx" 1 1
        done
        grep -F 'wrote streamed count matrix' "$out.log" >/dev/null
        test -s "$out/quant.json"
        # One-gene resampling is deterministic; bypass the tiny-cell shortcut.
        cmp "$out/alevin/quants_mat.mtx" "$out/alevin/bootstraps_mean.mtx"
        awk '!/^%/ {n++; if(n==1 && $3!=0) exit 1; if(n>1) exit 1}' \
            "$out/alevin/bootstraps_var.mtx"
        awk '!/^%/ {n++; if(n>1) sum+=$3} END {if(sum!=5) exit 1}' \
            "$out/alevin/quants_mat.mtx"
    done
    grep -F 'Full per-replicate MTX output is not supported' "$work/replicates.log" >/dev/null
    printf 'tx1\tgeneA\tS\ntx2\tgeneA\tU\n' >"$work/usa.tsv"
    run_logged "$work/usa.log" "$AF" quant -i "$work/permit" -m "$work/usa.tsv" \
        -o "$work/usa" -r cr-like -t 2 --use-mtx
    check_matrix "$work/usa/alevin/quants_mat.mtx" 1 3
    grep -Fx geneA-U "$work/usa/alevin/quants_mat_cols.txt" >/dev/null
    grep -Fx geneA-A "$work/usa/alevin/quants_mat_cols.txt" >/dev/null
    test -s "$work/usa/quant.json"

    # Portable output-create failure: a directory cannot be a matrix file.
    mkdir -p "$work/blocked/alevin/quants_mat.mtx"
    if "$AF" quant -i "$work/permit" -m "$work/t2g.tsv" \
        -o "$work/blocked" -r cr-like-em -t 2 --use-mtx >"$work/blocked.log" 2>&1; then
        fail "an invalid matrix destination was incorrectly accepted"
    fi
    grep -F 'could not create' "$work/blocked.log" >/dev/null || {
        tail -n 200 "$work/blocked.log" >&2; fail "missing create-error diagnostic";
    }
    test ! -e "$work/blocked/quant.json"

    # Minimal contained /dev (e.g. Apptainer Index) may omit /dev/full.
    # Never follow a dangling symlink and accidentally create a regular file.
    if [ ! -c /dev/full ]; then
        printf 'full-device fault probe unavailable: no /dev/full character device; output-create failure checked\n'
        return
    fi
    # Additional late-write fault when the backend exposes the real device.
    mkdir -p "$work/full/alevin"
    ln -s /dev/full "$work/full/alevin/quants_mat.mtx"
    if "$AF" quant -i "$work/permit" -m "$work/t2g.tsv" \
        -o "$work/full" -r cr-like-em -t 2 --use-mtx >"$work/full.log" 2>&1; then
        fail "a full output device was incorrectly accepted"
    fi
    grep -E 'could not (finalize|write)|No space left' "$work/full.log" >/dev/null || {
        tail -n 200 "$work/full.log" >&2; fail "missing output-error diagnostic";
    }
    test ! -e "$work/full/quant.json"
}

allowlist_check() {
    work="$TMP_ROOT/allowlist"
    mkdir -p "$work/root"
    printf 'AAAAAAAAAAAAAAAA\nCCCCCCCCCCCCCCCC\n' > "$work/list.txt"
    printf 'Synthetic engineering fixture; CC0-1.0. Not vendor data.\n' > "$work/LICENSE"
    sum=$(sha256sum "$work/list.txt" | awk '{print $1}')
    set -- prepare --resource-root "$work/root" --id local-test-v1 \
        --file "$work/list.txt" --sha256 "$sum" --license-file "$work/LICENSE" \
        --source urn:taffish:synthetic-allowlist-v1 --rights-reviewed --group-readable
    run_logged "$work/dry-run.log" alevin-fry-allowlist "$@" --dry-run
    test ! -e "$work/root/local-test-v1"
    run_logged "$work/prepare.log" alevin-fry-allowlist "$@"
    run_logged "$work/again.log" alevin-fry-allowlist "$@"
    grep -F 'already complete' "$work/again.log" >/dev/null
    run_logged "$work/verify.log" alevin-fry-allowlist verify \
        --resource-root "$work/root" --id local-test-v1 --sha256 "$sum"
    test "$(stat -c %a "$work/root/local-test-v1")" = 750
    test "$(stat -c %a "$work/root/local-test-v1/allowlist.txt")" = 640
    printf 'G\n' >> "$work/root/local-test-v1/allowlist.txt"
    if alevin-fry-allowlist verify --resource-root "$work/root" --id local-test-v1 > "$work/corrupt.log" 2>&1; then
        fail 'corrupt allowlist was accepted'
    fi
    grep -F 'checksum mismatch' "$work/corrupt.log" >/dev/null
}

case "$MODE" in
    buildtime)
        identity_check
        quick_interfaces_check
        rad_check
        ;;
    identity)
        identity_check
        ;;
    interfaces)
        interfaces_check
        ;;
    rad)
        rad_check
        ;;
    rna)
        rna_check
        ;;
    tiny)
        tiny_cell_check
        ;;
    infer)
        infer_check
        ;;
    streaming)
        streaming_check
        ;;
    allowlist)
        allowlist_check
        ;;
    *)
        fail "usage: $0 {buildtime|identity|interfaces|rad|rna|tiny|infer|streaming|allowlist} [tmp-root]"
        ;;
esac

printf 'alevin-fry smoke %s: PASS\n' "$MODE"
