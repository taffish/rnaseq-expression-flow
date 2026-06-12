#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)
index_flow_dir=$(CDPATH= cd "$project_dir/../rnaseq-index-flow" && pwd)

for target_dir in \
    "$bio_apps_dir/tools/fastqc/target" \
    "$bio_apps_dir/tools/fastp/target" \
    "$bio_apps_dir/tools/multiqc/target" \
    "$bio_apps_dir/tools/salmon/target" \
    "$bio_apps_dir/tools/bioconductor-rnaseq/target" \
    "$index_flow_dir/target"
do
    if [ -d "$target_dir" ]; then
        PATH="$target_dir:$PATH"
    fi
done
export PATH

if ! command -v taf >/dev/null 2>&1; then
    echo "smoke: taf command not found in PATH." >&2
    exit 127
fi

if ! command -v taffish >/dev/null 2>&1; then
    echo "smoke: taffish command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-fastqc-v0.12.1-r1 \
    taf-fastp-v1.3.3-r3 \
    taf-multiqc-v1.35-r2 \
    taf-salmon-v1.11.4-r1 \
    taf-bioconductor-rnaseq-v3.23-r1
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "smoke: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

tmpdir=$(mktemp -d "$project_dir/.taf-smoke.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

cd "$project_dir"

echo "[SMOKE] taf check"
taf check

echo "[SMOKE] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-expression-flow-v0.2.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "smoke: built flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

echo "[SMOKE] help and version"
"$flow_cmd" --help >/dev/null
"$flow_cmd" --version >/dev/null

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

echo "[SMOKE] build upstream rnaseq-index-flow"
(
    cd "$index_flow_dir"
    taf check
    taf build
)
index_flow_cmd="$index_flow_dir/target/taf-rnaseq-index-flow-v0.2.0-r1"
if [ ! -x "$index_flow_cmd" ]; then
    echo "smoke: built index flow command is missing or not executable: $index_flow_cmd" >&2
    exit 1
fi

echo "[SMOKE] setup reference bundle via rnaseq-index-flow target"
(
    cd "$run_dir"
    "$index_flow_cmd" \
        --transcripts "$project_dir/testdata/transcripts.fa" \
        --tx2gene "$project_dir/testdata/tx2gene.tsv" \
        --outdir ref-out \
        --threads 1 \
        --indexer salmon \
        --kmer 15
)
test -s "$run_dir/ref-out/03_results/salmon_index/info.json"
test -s "$run_dir/ref-out/03_results/tx2gene.tsv"

echo "[SMOKE] rnaseq-expression-flow tiny fixture with --trim"
(
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$project_dir/testdata/samples.tsv" \
        --index "$run_dir/ref-out/03_results/salmon_index" \
        --tx2gene "$run_dir/ref-out/03_results/tx2gene.tsv" \
        --outdir expression-out \
        --threads 1 \
        --library-type A \
        --trim \
        --min-assigned-frags 1 \
        @multiqc-step: --quiet @:
)
cd "$project_dir"

out="$run_dir/expression-out"

echo "[SMOKE] output checks"
test -s "$out/00_inputs/samples.tsv"
test -s "$out/00_inputs/samples.normalized.tsv"
test -s "$out/00_inputs/input_files.tsv"
test -s "$out/00_inputs/tx2gene.tsv"
test -s "$out/01_logs/flow.log"
test -s "$out/01_logs/steps/01_validate_inputs.log"
test -s "$out/01_logs/steps/02_fastqc.log"
test -s "$out/01_logs/steps/02_fastqc.S1.log"
test -s "$out/01_logs/steps/03_fastp.log"
test -s "$out/01_logs/steps/03_fastp.S1.log"
test -s "$out/01_logs/steps/04_salmon_quant.log"
test -s "$out/01_logs/steps/04_salmon_quant.S1.log"
test -s "$out/01_logs/steps/05_tximport.log"
test -s "$out/01_logs/steps/05_salmon_quantmerge_counts.log"
test -s "$out/01_logs/steps/05_salmon_quantmerge_tpm.log"
test -s "$out/01_logs/steps/06_multiqc.log"
test -s "$out/02_intermediate/trimmed/S1.clean.fastq.gz"
test -s "$out/03_results/fastp/S1.fastp.json"
test -s "$out/03_results/salmon/S1/quant.sf"
test -s "$out/03_results/salmon/S2/quant.sf"
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

grep -F 'S1' "$out/04_reports/quant_files.tsv" >/dev/null
grep -F 'S2' "$out/04_reports/quant_files.tsv" >/dev/null
grep -F 'geneA' "$out/03_results/matrices/gene_counts.tsv" >/dev/null
grep -F 'geneB' "$out/03_results/matrices/gene_counts.tsv" >/dev/null
grep -F 'tx1' "$out/03_results/matrices/transcript_counts.tsv" >/dev/null
grep -F 'tx2' "$out/03_results/matrices/transcript_counts.tsv" >/dev/null
grep -F 'taf-fastqc-v0.12.1-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-fastp-v1.3.3-r3' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-salmon-v1.11.4-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-bioconductor-rnaseq-v3.23-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-multiqc-v1.35-r2' "$out/04_reports/commands.sh" >/dev/null
grep -F -- '--quiet --quiet' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-salmon	1.11.4-r1' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'sample_count	2' "$out/04_reports/flow_summary.tsv" >/dev/null
grep -F '"flow": "rnaseq-expression-flow"' "$out/run.manifest.json" >/dev/null
grep -F '"quantifier": "salmon"' "$out/run.manifest.json" >/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

echo "[SMOKE] existing outdir is refused"
if (
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$project_dir/testdata/samples.tsv" \
        --index "$run_dir/ref-out/03_results/salmon_index" \
        --tx2gene "$run_dir/ref-out/03_results/tx2gene.tsv" \
        --outdir expression-out \
        --threads 1 \
        --min-assigned-frags 1
) >/dev/null 2>&1; then
    echo "smoke: existing outdir was not refused." >&2
    exit 1
fi

echo "[SMOKE] --force rerun without FastQC or trimming"
(
    cd "$run_dir"
    "$flow_cmd" \
        --samples "$project_dir/testdata/samples.tsv" \
        --index "$run_dir/ref-out/03_results/salmon_index" \
        --tx2gene "$run_dir/ref-out/03_results/tx2gene.tsv" \
        --outdir expression-out \
        --threads 1 \
        --skip-fastqc \
        --min-assigned-frags 1 \
        --force
)
test -s "$out/03_results/salmon/S1/quant.sf"
test -s "$out/03_results/matrices/gene_counts.tsv"
grep -F 'skip_fastqc	true' "$out/04_reports/flow_summary.tsv" >/dev/null
test ! -e "$out/02_intermediate/trimmed/S1.clean.fastq.gz"

stray=$(find "$run_dir" -mindepth 1 -maxdepth 1 ! -name ref-out ! -name expression-out -print)
if [ -n "$stray" ]; then
    echo "smoke: flow wrote unexpected files outside outdir:" >&2
    printf '%s\n' "$stray" >&2
    exit 1
fi

echo "[SMOKE] ok"
