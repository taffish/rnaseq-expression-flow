#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)
rnaseq_root=$(CDPATH= cd "$project_dir/../.." && pwd)
index_flow_dir="$rnaseq_root/subflows/rnaseq-index-flow"
default_data_root=$(CDPATH= cd "$rnaseq_root/test-data/yeast/data/03_results" 2>/dev/null && pwd || printf '%s\n' "$rnaseq_root/test-data/yeast/data/03_results")
data_root=${TAFFISH_RNASEQ_TESTDATA:-$default_data_root}

for target_dir in \
    "$bio_apps_dir/tools/fastqc/target" \
    "$bio_apps_dir/tools/fastp/target" \
    "$bio_apps_dir/tools/multiqc/target" \
    "$bio_apps_dir/tools/salmon/target" \
    "$bio_apps_dir/tools/bioconductor-rnaseq/target" \
    "$bio_apps_dir/tools/agat/target" \
    "$bio_apps_dir/tools/gffread/target" \
    "$bio_apps_dir/tools/kallisto/target" \
    "$index_flow_dir/target"
do
    if [ -d "$target_dir" ]; then
        PATH="$target_dir:$PATH"
    fi
done
export PATH

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

skip_formal() {
    echo "formal: skipped: $*" >&2
    exit 0
}

if [ ! -d "$data_root" ]; then
    skip_formal "RNA-seq formal data root not found: $data_root"
fi

fastq_samples="$data_root/yeast-snf2-fastq-mini-v1/samples.tsv"
genome="$data_root/yeast-reference-sgd-r64.4.1-v1/reference/genome/yeast_s288c_reference_genome_R64-4-1.fa"
annotation="$data_root/yeast-reference-sgd-r64.4.1-v1/reference/annotation/yeast_s288c_gene_annotation_R64-4-1.gff3"

[ -s "$fastq_samples" ] || skip_formal "missing yeast FASTQ samples.tsv: $fastq_samples"
[ -s "$genome" ] || skip_formal "missing yeast reference genome FASTA: $genome"
[ -s "$annotation" ] || skip_formal "missing yeast reference GFF3 annotation: $annotation"

if ! command -v taf >/dev/null 2>&1; then
    echo "formal: taf command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-fastqc-v0.12.1-r1 \
    taf-fastp-v1.3.3-r3 \
    taf-multiqc-v1.35-r2 \
    taf-salmon-v1.11.4-r1 \
    taf-bioconductor-rnaseq-v3.23-r1 \
    taf-agat-v1.7.0-r1 \
    taf-gffread-v0.12.9-r1
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "formal: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

tmpdir=$(mktemp -d "$project_dir/.taf-formal.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

echo "[FORMAL] build rnaseq-index-flow"
(
    cd "$index_flow_dir"
    taf check
    taf build
)

index_flow_cmd="$index_flow_dir/target/taf-rnaseq-index-flow-v0.1.0-r1"
if [ ! -x "$index_flow_cmd" ]; then
    echo "formal: built index flow command is missing or not executable: $index_flow_cmd" >&2
    exit 1
fi

cd "$project_dir"

echo "[FORMAL] taf check"
taf check

echo "[FORMAL] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-expression-flow-v0.1.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "formal: built expression flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

formal_samples="$run_dir/samples.subset.tsv"
awk -F '\t' -v OFS='\t' '
    NR == 1 {
        for (i = 1; i <= NF; i++) col[$i] = i
        if (!("sample_id" in col) || !("read1" in col) || !("condition" in col)) {
            print "formal: samples table must contain sample_id, read1, and condition" > "/dev/stderr"
            exit 2
        }
        print "sample_id", "read1", "condition"
        next
    }
    $0 == "" { next }
    $(col["condition"]) == "snf2_KO" && ko < 2 {
        print $(col["sample_id"]), base "/" $(col["read1"]), $(col["condition"])
        ko++
        next
    }
    $(col["condition"]) == "WT" && wt < 2 {
        print $(col["sample_id"]), base "/" $(col["read1"]), $(col["condition"])
        wt++
        next
    }
    END {
        if (ko < 2 || wt < 2) {
            print "formal: need at least 2 snf2_KO and 2 WT samples" > "/dev/stderr"
            exit 3
        }
    }
' base="$(dirname "$fastq_samples")" "$fastq_samples" > "$formal_samples"

echo "[FORMAL] rnaseq-index-flow yeast reference"
(
    cd "$run_dir"
    "$index_flow_cmd" \
        --genome "$genome" \
        --annotation "$annotation" \
        --outdir ref-out \
        --threads 2 \
        --indexer salmon
)

test -s "$run_dir/ref-out/03_results/salmon_index/info.json"
test -s "$run_dir/ref-out/03_results/tx2gene.tsv"

echo "[FORMAL] rnaseq-expression-flow yeast subset"
(
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$formal_samples" \
        --index "$run_dir/ref-out/03_results/salmon_index" \
        --tx2gene "$run_dir/ref-out/03_results/tx2gene.tsv" \
        --outdir expression-out \
        --threads 2 \
        --skip-fastqc \
        --min-assigned-frags 1
)

out="$run_dir/expression-out"
test -s "$out/03_results/salmon/SNF2KO_01/quant.sf"
test -s "$out/03_results/salmon/SNF2KO_02/quant.sf"
test -s "$out/03_results/salmon/WT_01/quant.sf"
test -s "$out/03_results/salmon/WT_02/quant.sf"
test -s "$out/03_results/matrices/gene_counts.tsv"
test -s "$out/03_results/matrices/gene_tpm.tsv"
test -s "$out/03_results/matrices/gene_length.tsv"
test -s "$out/03_results/matrices/transcript_counts.tsv"
test -s "$out/03_results/matrices/transcript_tpm.tsv"
test -s "$out/04_reports/quant_files.tsv"
test -s "$out/04_reports/expression_summary.tsv"
test -s "$out/04_reports/multiqc_report.html"
test -s "$out/04_reports/commands.sh"
test -s "$out/04_reports/versions.tsv"
test -s "$out/04_reports/methods.txt"
test -s "$out/04_reports/flow_summary.tsv"
test -s "$out/run.manifest.json"

grep -F 'sample_count	4' "$out/04_reports/flow_summary.tsv" >/dev/null
grep -F 'taf-salmon-v1.11.4-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F '"flow": "rnaseq-expression-flow"' "$out/run.manifest.json" >/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

echo "[FORMAL] ok"
