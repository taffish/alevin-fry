#!/bin/sh
# Offline import of an operator-approved, fixed gene ID/name mapping.
set -eu
export LC_ALL=C
die() { printf 'qcatch-gene-map: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage:
  qcatch-gene-map prepare --resource-root DIR --id ID --file FILE
    --sha256 HEX --license-file FILE --source URL --rights-reviewed
    [--group-readable] [--dry-run]
  qcatch-gene-map verify --resource-root DIR --id ID [--sha256 HEX]

Import one locally acquired UTF-8, two-column, headerless gene ID/name TSV.
No download, license acceptance, species choice or upstream algorithm rewrite.
ID must identify the reference/source revision, not the QCatch version.
Review your rights and the scope of authorized users before preparing a copy.
The existing resource root must be writable and controlled by its administrator.
Personal resources are 0700/0600; --group-readable uses 0750/0640 and the root's
group. Restrict that group to authorized users. No world-readable vendor data.
Identical complete imports are skipped; corrupt/conflicting IDs fail closed.
There is no overwrite/force: preserve the old receipt and use a new ID.
Verify checks integrity and optional expected data SHA, not legal authorization.
Pass DIR/ID/gene-map.tsv explicitly to qcatch --gene_id2name_file.
EOF
}
mode=${1:---help}
case "$mode" in --help|-h) usage; exit 0;; prepare|verify) shift;; *) usage >&2; exit 2;; esac
root= id= input= expected= notice= source= reviewed=0 group_read=0 dry_run=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --resource-root|--id|--file|--sha256|--license-file|--source)
            [ "$#" -ge 2 ] || die "missing value for $1"
            case "$1" in
                --resource-root) root=$2;; --id) id=$2;; --file) input=$2;;
                --sha256) expected=$2;; --license-file) notice=$2;; --source) source=$2;;
            esac
            shift 2;;
        --rights-reviewed) reviewed=1; shift;;
        --group-readable) group_read=1; shift;;
        --dry-run) dry_run=1; shift;;
        --help|-h) usage; exit 0;;
        *) die "unknown option: $1";;
    esac
done
case "$id" in ''|[!A-Za-z0-9]*|*[!A-Za-z0-9_.-]*) die 'use an alphanumeric-leading ID containing only letters, digits, _, . or -';; esac
[ "${#id}" -le 100 ] || die 'ID is too long'
case "$root" in /*) :;; *) die '--resource-root must be an existing absolute directory';; esac
[ -d "$root" ] || die 'resource root does not exist; create a private or authorized-group directory first'
root=$(cd "$root" && pwd -P)
final="$root/$id"
hash() { sha256sum "$1" | awk '{print $1}'; }
check_sha() { [ "${#1}" -eq 64 ] && ! printf '%s' "$1" | grep -q '[^a-f0-9]'; }
check_encoding() {
    python3 -c 'import sys; data=open(sys.argv[1], encoding="utf-8").read(); sys.exit("\x00" in data)' "$1" \
        || die 'gene mapping must be valid UTF-8 without NUL bytes'
}
if [ -n "$expected" ]; then check_sha "$expected" || die '--sha256 needs 64 lowercase hexadecimal characters'; fi

verify() {
    candidate=$1
    [ -d "$candidate" ] && [ ! -L "$candidate" ] || die 'missing resource or symlinked member root'
    for member in gene-map.tsv LICENSE resource.tsv SHA256SUMS READY; do
        [ -f "$candidate/$member" ] && [ ! -L "$candidate/$member" ] || die "missing/non-regular member: $member"
    done
    for member in "$candidate"/* "$candidate"/.[!.]* "$candidate"/..?*; do
        if [ -e "$member" ] || [ -L "$member" ]; then
            case "${member##*/}" in gene-map.tsv|LICENSE|resource.tsv|SHA256SUMS|READY) :;; *) die 'unexpected resource member';; esac
        fi
    done
    awk 'NF!=2 || length($1)!=64 || $1~/[^a-f0-9]/ {bad=1}
         $2=="gene-map.tsv" {a++} $2=="LICENSE" {l++} $2=="resource.tsv" {m++}
         END {exit(bad || NR!=3 || a!=1 || l!=1 || m!=1)}' "$candidate/SHA256SUMS" || die 'invalid inventory'
    [ "$(hash "$candidate/SHA256SUMS")" = "$(cat "$candidate/READY")" ] || die 'invalid READY inventory digest'
    (cd "$candidate" && sha256sum --status -c SHA256SUMS) || die 'resource checksum mismatch'
    awk -F '\t' -v id="$id" '
         NF!=2 || seen[$1]++ {bad=1}
         $1 !~ /^(schema|id|source|sha256|license_sha256|bytes|records_and_columns|access|prepared_utc)$/ {bad=1}
         $1=="schema" && $2=="taffish.qcatch.gene-map.v1" {s++}
         $1=="id" && $2==id {i++}
         END {exit(bad || NR!=9 || s!=1 || i!=1)}' "$candidate/resource.tsv" || die 'resource identity mismatch'
    for pair in "sha256 gene-map.tsv" "license_sha256 LICENSE"; do
        set -- $pair
        [ "$(awk -F '\t' -v key="$1" '$1==key {print $2}' "$candidate/resource.tsv")" = "$(hash "$candidate/$2")" ] || die 'resource metadata checksum mismatch'
    done
    [ -s "$candidate/LICENSE" ] || die 'empty license notice'
    recorded_bytes=$(awk -F '\t' '$1=="bytes" {print $2}' "$candidate/resource.tsv")
    [ "$recorded_bytes" = "$(wc -c < "$candidate/gene-map.tsv" | tr -d ' ')" ] || die 'resource byte count mismatch'
    check_encoding "$candidate/gene-map.tsv"
    verified_stats=$(awk -F '\t' 'NF!=2 || $1=="" || $2=="" || /\r/ || seen[$1]++ {bad=1}
        END {if(bad || NR==0) exit 1; print NR, 2}' "$candidate/gene-map.tsv") || die 'invalid gene ID/name mapping'
    [ "$verified_stats" = "$(awk -F '\t' '$1=="records_and_columns" {print $2}' "$candidate/resource.tsv")" ] || die 'resource record count mismatch'
    scope=$(awk -F '\t' '$1=="access" {print $2}' "$candidate/resource.tsv")
    case "$scope" in personal) dmode=700; fmode=600;; authorized-group) dmode=750; fmode=640;; *) die 'invalid access scope';; esac
    [ "$(stat -c %a "$candidate")" = "$dmode" ] || die 'resource directory permissions drifted'
    for member in "$candidate"/*; do
        [ "$(stat -c %a "$member")" = "$fmode" ] || die 'resource file permissions drifted'
    done
    if [ -n "$expected" ]; then
        [ "$(hash "$candidate/gene-map.tsv")" = "$expected" ] || die 'expected data SHA256 mismatch'
    fi
}
if [ "$mode" = verify ]; then
    [ -z "$input$notice$source" ] && [ "$reviewed$group_read$dry_run" = 000 ] || die 'prepare-only options passed to verify'
    verify "$final"
    printf 'verified: %s/gene-map.tsv\n' "$final"
    exit 0
fi
[ "$reviewed" -eq 1 ] || die 'review acquisition/internal-sharing rights, then pass --rights-reviewed; this does not grant permission'
[ -n "$expected" ] || die '--sha256 is required'
[ -f "$input" ] && [ -s "$input" ] && [ ! -L "$input" ] || die 'input must be a nonempty regular file, not a symlink'
[ -f "$notice" ] && [ -s "$notice" ] && [ ! -L "$notice" ] || die 'license-file must contain the applicable notice, not a symlink'
case "$source" in https://*|http://*|urn:*) :;; *) die 'record a fixed source URL or local provenance URN';; esac
if printf '%s' "$source" | grep -q '[[:cntrl:]]'; then die 'source contains a control character'; fi
[ "$(hash "$input")" = "$expected" ] || die 'input SHA256 mismatch'
notice_sha=$(hash "$notice")
check_encoding "$input"
stats=$(awk -F '\t' 'NF!=2 || $1=="" || $2=="" || /\r/ || seen[$1]++ {bad=1}
             END {if(bad || NR==0) exit 1; print NR, 2}' "$input") || die 'expected unique gene IDs and two nonempty TSV columns (no header or CRLF)'
bytes=$(wc -c < "$input" | tr -d ' ')
notice_bytes=$(wc -c < "$notice" | tr -d ' ')
available=$(df -Pk "$root" | awk 'END {print $4}')
needed=$(( (bytes + notice_bytes) / 1024 + 1024 ))
[ "$available" -ge "$needed" ] || die 'insufficient space for staged copy plus 1 MiB reserve'
dir_mode=700 file_mode=600 access=personal
if [ "$group_read" -eq 1 ]; then dir_mode=750; file_mode=640; access=authorized-group; fi
root_gid=$(stat -c %g "$root")
printf 'id=%s source=%s sha256=%s bytes=%s records/length=%s access=%s group=%s\n' \
    "$id" "$source" "$expected" "$bytes" "$stats" "$access" "$root_gid"
printf 'license_file=%s license_sha256=%s license_bytes=%s rights=operator-reviewed\n' \
    "$notice" "$notice_sha" "$notice_bytes"
if [ "$dry_run" -eq 1 ]; then
    printf 'dry-run: would verify/copy to %s; no files changed\n' "$final"
    exit 0
fi
stage= stage_identity= lock_identity= interrupted=0
lock="$root/.$id.lock"
identity() { stat -c '%d:%i' -- "$1"; }
cleanup() {
    # Only this transaction's unchanged endpoints belong to us. Never sweep
    # old staging directories or follow a replaced endpoint outside the root.
    if [ -n "$stage_identity" ] && [ -d "$stage" ] && [ ! -L "$stage" ] &&
       [ "$(identity "$stage")" = "$stage_identity" ]; then rm -rf -- "$stage"; fi
    if [ -n "$lock_identity" ] && [ -d "$lock" ] && [ ! -L "$lock" ] &&
       [ "$(identity "$lock")" = "$lock_identity" ]; then rmdir -- "$lock"; fi
}
trap cleanup EXIT
# Defer termination across endpoint creation and ownership capture. Otherwise a
# signal between mkdir/mktemp and assignment can strand an unrecorded endpoint.
trap 'interrupted=130' INT
trap 'interrupted=143' TERM
umask 077
mkdir -- "$lock" 2>/dev/null || die 'resource locked or root not writable; do not remove another live import lock'
lock_identity=$(identity "$lock")
[ "$interrupted" -eq 0 ] || exit "$interrupted"
trap 'exit 130' INT
trap 'exit 143' TERM
if [ -e "$final" ] || [ -L "$final" ]; then
    verify "$final"
    [ "$(hash "$final/LICENSE")" = "$notice_sha" ] || die 'existing ID has a different license notice'
    grep -Fx "$(printf 'source\t%s' "$source")" "$final/resource.tsv" >/dev/null || die 'existing ID has a different source'
    grep -Fx "$(printf 'access\t%s' "$access")" "$final/resource.tsv" >/dev/null || die 'existing ID has a different access scope'
    printf 'already complete: %s (unchanged)\n' "$final"
    exit 0
fi
trap 'interrupted=130' INT
trap 'interrupted=143' TERM
stage=$(mktemp -d "$root/.$id.stage.XXXXXX")
stage_identity=$(identity "$stage")
[ "$interrupted" -eq 0 ] || exit "$interrupted"
trap 'exit 130' INT
trap 'exit 143' TERM
cp -- "$input" "$stage/gene-map.tsv"
cp -- "$notice" "$stage/LICENSE"
[ "$(hash "$stage/gene-map.tsv")" = "$expected" ] || die 'source changed during copy'
[ "$(hash "$stage/LICENSE")" = "$notice_sha" ] || die 'notice changed during copy'
{
    printf 'schema\ttaffish.qcatch.gene-map.v1\nid\t%s\nsource\t%s\n' "$id" "$source"
    printf 'sha256\t%s\nlicense_sha256\t%s\nbytes\t%s\n' "$expected" "$notice_sha" "$bytes"
    printf 'records_and_columns\t%s\naccess\t%s\nprepared_utc\t%s\n' "$stats" "$access" "$(date -u +%FT%TZ)"
} > "$stage/resource.tsv"
(cd "$stage" && sha256sum gene-map.tsv LICENSE resource.tsv > SHA256SUMS)
hash "$stage/SHA256SUMS" > "$stage/READY"
chgrp -- "$root_gid" "$stage" "$stage"/*
chmod "$file_mode" "$stage"/*
chmod "$dir_mode" "$stage"
verify "$stage"
mv -T -n -- "$stage" "$final"
[ ! -e "$stage" ] || die 'destination appeared during import; refusing overwrite'
stage= stage_identity=
printf 'prepared: %s/gene-map.tsv\n' "$final"
