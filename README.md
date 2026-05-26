# rnaseq-expression-flow

`taf-rnaseq-expression-flow` quantifies bulk RNA-seq FASTQ samples against a
prebuilt Salmon transcriptome index and writes per-sample `quant.sf` files,
gene-level matrices, transcript-level matrices, MultiQC reports, logs,
commands, versions, methods, and a manifest under one explicit output
directory.

Package identity:

- name: `rnaseq-expression-flow`
- command: `taf-rnaseq-expression-flow`
- kind: `flow`
- version: `0.1.0-r1`
- license: Apache-2.0

## RNA-seq Flow Position

This app is a reusable subflow in the TAFFISH bulk RNA-seq flow family. It can
be run directly for Salmon-first expression quantification, and it is also
designed to be called by the future `rnaseq-standard-flow` umbrella. The
umbrella should reuse this flow's stable expression-matrix contract rather than
duplicate its quantification and tximport logic.

## Scope

r1 supports:

- single-end and paired-end FASTQ sample tables
- Salmon transcript quantification with `--library-type A` by default
- optional raw read FastQC
- optional fastp trimming before Salmon quantification
- tximport gene-level count, TPM, and length matrices
- Salmon transcript-level count and TPM matrices
- MultiQC report collection
- fixed output tree under `<outdir>/`
- input table snapshots under `<outdir>/00_inputs/`
- provenance files: `commands.sh`, `versions.tsv`, `methods.txt`,
  `flow_summary.tsv`, `expression_summary.tsv`, `quant_files.tsv`, and
  `run.manifest.json`

r1 is Salmon-first. It does not build indexes, perform differential expression,
run genome alignment, run BAM-level RNA-seq QC, infer experimental design, or
download reference data during normal execution. Kallisto quantification can be
added in a later release because `rnaseq-index-flow` can already produce a
Kallisto index, but this release intentionally keeps one stable quantification
path.

## Dependencies

The flow depends on version-pinned TAFFISH tool apps for biological work:

| Dependency | Version | Role |
| --- | --- | --- |
| `taf-fastqc` | `0.12.1-r1` | optional raw FASTQ QC |
| `taf-fastp` | `1.3.3-r3` | optional trimming |
| `taf-salmon` | `1.11.4-r1` | transcript quantification and transcript matrix merge |
| `taf-bioconductor-rnaseq` | `3.23-r1` | tximport gene-level matrices |
| `taf-multiqc` | `1.35-r2` | HTML and JSON report aggregation |

The script also uses ordinary shell utilities (`sh`, `awk`, `sed`, `date`,
`mkdir`, `cp`, `rm`, `grep`, and related POSIX tools) for validation,
bookkeeping, and provenance. It does not call host-installed `fastqc`,
`fastp`, `salmon`, `R`, `tximport`, or `multiqc`.

## Usage

Use the Salmon index and `tx2gene.tsv` produced by `rnaseq-index-flow`:

```sh
taf-rnaseq-expression-flow \
  --samples samples.tsv \
  --index ref-out/03_results/salmon_index \
  --tx2gene ref-out/03_results/tx2gene.tsv \
  --outdir expression-out \
  --threads 4
```

Run read trimming before quantification:

```sh
taf-rnaseq-expression-flow \
  --samples samples.tsv \
  --index ref-out/03_results/salmon_index \
  --tx2gene ref-out/03_results/tx2gene.tsv \
  --outdir expression-out \
  --threads 8 \
  --trim
```

Skip raw FastQC when upstream read QC has already been performed:

```sh
taf-rnaseq-expression-flow \
  --samples samples.tsv \
  --index ref-out/03_results/salmon_index \
  --tx2gene ref-out/03_results/tx2gene.tsv \
  --outdir expression-out \
  --skip-fastqc
```

## Parameters

Required input/output:

- `--samples PATH`: tab-delimited FASTQ sample table.
- `--index PATH`: Salmon transcriptome index directory. The directory must
  contain `info.json`.
- `--tx2gene PATH`: two-column transcript-to-gene table with `tx_id` and
  `gene_id` columns.
- `--outdir PATH`, `-o PATH`: output directory. The flow refuses to run if it
  already exists unless `--force` is used.

Common controls:

- `--threads N`, `-t N`: threads for FastQC, fastp, and Salmon. Default: `1`.
- `--library-type TYPE`: Salmon library type. Default: `A`.
- `--quantifier salmon`: quantifier selection. r1 accepts only `salmon`.
- `--trim`: run fastp and quantify the trimmed FASTQ files.
- `--skip-fastqc`: skip raw FASTQ FastQC.
- `--min-assigned-frags N`: Salmon `--minAssignedFrags` value. Default: `10`.
- `--counts-from-abundance MODE`: tximport mode, one of `no`, `scaledTPM`,
  `lengthScaledTPM`, or `dtuScaledTPM`. Default: `no`.
- `--force`: replace the standard rnaseq-expression-flow output files inside
  an existing output directory.

## Sample Table

Single-end input:

```text
sample_id	read1
S1	reads/S1.fq.gz
S2	reads/S2.fq.gz
```

Paired-end input:

```text
sample_id	read1	read2
S1	reads/S1_R1.fq.gz	reads/S1_R2.fq.gz
S2	reads/S2_R1.fq.gz	reads/S2_R2.fq.gz
```

Rules:

- `sample_id` must be unique and non-empty.
- `sample_id` may contain letters, numbers, dots, underscores, and hyphens.
- Relative FASTQ paths are interpreted relative to the sample table location.
- If `read2` is present and non-empty, the sample is treated as paired-end.
- Other columns such as `condition`, `batch`, `library_layout`, and
  `strandedness` are preserved in the input snapshot but are not interpreted by
  this r1 expression flow.

## Outputs

All flow-created outputs are written under `<outdir>/`:

```text
<outdir>/
  00_inputs/
    samples.tsv
    samples.normalized.tsv
    input_files.tsv
    tx2gene.tsv
  01_logs/
    flow.log
    steps/
      01_validate_inputs.log
      02_fastqc.log
      02_fastqc.<sample>.log
      03_fastp.log
      03_fastp.<sample>.log
      04_salmon_quant.log
      04_salmon_quant.<sample>.log
      05_tximport.log
      05_salmon_quantmerge_counts.log
      05_salmon_quantmerge_tpm.log
      06_multiqc.log
  02_intermediate/
    trimmed/
    tximport/
  03_results/
    fastqc/
    fastp/
    salmon/
      <sample>/quant.sf
    matrices/
      gene_counts.tsv
      gene_tpm.tsv
      gene_length.tsv
      transcript_counts.tsv
      transcript_tpm.tsv
  04_reports/
    multiqc_report.html
    expression_summary.tsv
    quant_files.tsv
    commands.sh
    versions.tsv
    methods.txt
    flow_summary.tsv
  run.manifest.json
```

Downstream RNA-seq flows should consume:

- `03_results/matrices/gene_counts.tsv`
- `03_results/matrices/gene_tpm.tsv`
- `03_results/matrices/transcript_counts.tsv`
- `04_reports/quant_files.tsv`
- `00_inputs/tx2gene.tsv`

## Data Flow

1. Validate sample table, Salmon index, `tx2gene.tsv`, and output directory.
2. Copy `samples.tsv` and `tx2gene.tsv` into `<outdir>/00_inputs/`, then write
   normalized sample and input-file tables with absolute FASTQ paths.
3. Run FastQC on raw FASTQ files unless `--skip-fastqc` is set.
4. Run fastp only when `--trim` is set; otherwise quantify the original FASTQ
   files directly.
5. Run Salmon quant once per sample.
6. Run `rnaseq-tximport` to produce gene-level count, TPM, and length matrices.
7. Run Salmon `quantmerge` to produce transcript-level count and TPM matrices.
8. Run MultiQC over the output tree.
9. Write summary tables, commands, versions, methods, logs, and manifest.

## Resource Notes

For smoke fixtures, `--threads 1` is enough. For small teaching datasets, start
with `--threads 2` to `--threads 4`. For ordinary bulk RNA-seq projects, use
`--threads 4` to `--threads 8` and place `<outdir>` on storage with enough room
for Salmon output, optional trimmed FASTQ files, FastQC output, and MultiQC
files.

Runtime mostly follows FASTQ size and sample count. Salmon quantification and
fastp are usually the dominant CPU users. `--trim` can substantially increase
disk usage because cleaned FASTQ files are kept under
`02_intermediate/trimmed/`. Gene-level matrix generation is usually light
compared with per-sample quantification.

The flow has no GPU requirement and performs no runtime downloads. Platform
support follows the five dependency apps listed above and the configured
TAFFISH container backend. Local maintenance smoke defaults to Podman while
respecting an already set `TAFFISH_CONTAINER_BACKEND`.

## Boundaries

The flow writes only under `<outdir>/` and does not modify input FASTQ files,
the Salmon index, or `tx2gene.tsv`. It records absolute input paths in
provenance files but does not copy read data into the output directory, because
duplicating FASTQ files would make real runs unnecessarily large.

`--library-type A` asks Salmon to infer library type. For production analyses,
confirm the library type with the sequencing protocol or upstream QC and record
any deliberate override. This flow does not decide experimental groups or
contrasts; pass the matrices and metadata to `rnaseq-de-flow` for differential
expression.

`counts-from-abundance=no` preserves tximport's default estimated counts. If a
downstream method expects scaled TPM-derived counts, choose the appropriate
tximport mode explicitly and keep that setting with the run provenance.

## Troubleshooting

If the flow fails, check `01_logs/flow.log` first and then the matching file
under `01_logs/steps/`. Per-sample FastQC, fastp, and Salmon logs include the
sample ID in the filename.

If a dependency wrapper such as `taf-salmon-v1.11.4-r1` is missing, expose or
build the dependency app before running this flow. If `<outdir>` already exists,
choose a new output directory or use `--force` after confirming that it contains
only replaceable rnaseq-expression-flow outputs.

## Testing

`tests/smoke.sh` builds the flow, creates a tiny Salmon index from a
two-transcript fixture, runs two single-end samples through FastQC, fastp,
Salmon, tximport, quantmerge, and MultiQC, and checks key results, logs,
commands, versions, manifest, output-directory refusal, `--force`, and current
directory cleanliness.

`tests/formal.sh` uses the central RNA-seq yeast mini data under
`repos/apps/bio/flows/rna-seq/test-data/yeast/data/03_results`. It builds a
temporary reference with `rnaseq-index-flow`, runs a small balanced sample
subset through this expression flow, and checks the same key output contract. If
the central FASTQ or reference resources are not present, it prints
`formal: skipped` with the missing resource and exits successfully without
downloading anything. The central data tree can be prepared with
`repos/apps/bio/flows/rna-seq/test-data/yeast/rnaseq-yeast-get-data`; downstream
formal tests read it via `TAFFISH_RNASEQ_TESTDATA` or the default local
`test-data/yeast/data/03_results` path.
