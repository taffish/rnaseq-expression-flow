rnaseq-expression-flow 0.1.0-r1

Purpose:
  Quantify bulk RNA-seq FASTQ samples against a prebuilt Salmon transcriptome
  index, then write per-sample quant.sf files, gene-level matrices,
  transcript-level matrices, MultiQC reports, logs, commands, versions,
  methods, and a manifest under one explicit output directory.

Flow family role:
  This is a TAFFISH RNA-seq subflow. It can be run directly for Salmon-first
  expression quantification, and its stable matrix outputs are intended for
  future rnaseq-standard-flow orchestration.

Usage:
  taf-rnaseq-expression-flow \
    --samples samples.tsv \
    --index ref-out/03_results/salmon_index \
    --tx2gene ref-out/03_results/tx2gene.tsv \
    --outdir expression-out \
    [options]

Required inputs:
  --samples PATH
      Tab-delimited FASTQ sample table. Required columns are sample_id and
      read1. Optional read2 enables paired-end mode for that sample. Relative
      FASTQ paths are interpreted relative to the sample table location.

  --index PATH
      Salmon transcriptome index directory. The directory must contain
      info.json.

  --tx2gene PATH
      Tab-delimited transcript-to-gene table with columns tx_id and gene_id.

Required output:
  --outdir PATH, -o PATH
      Output directory. The flow refuses to run if PATH already exists unless
      --force is used.

Common options:
  --threads N, -t N
      Threads for FastQC, fastp, and Salmon. Default: 1.

  --library-type TYPE
      Salmon library type. Default: A.

  --quantifier salmon
      Quantifier selection. r1 accepts only salmon.

  --trim
      Run fastp first and quantify the cleaned FASTQ files.

  --skip-fastqc
      Skip raw FASTQ FastQC.

  --min-assigned-frags N
      Salmon --minAssignedFrags value. Default: 10.

  --counts-from-abundance MODE
      tximport countsFromAbundance value. One of no, scaledTPM,
      lengthScaledTPM, or dtuScaledTPM. Default: no.

  --force
      Replace the standard rnaseq-expression-flow output files inside an
      existing output directory.

Sample table examples:
  Single-end:
    sample_id<TAB>read1
    S1<TAB>reads/S1.fq.gz
    S2<TAB>reads/S2.fq.gz

  Paired-end:
    sample_id<TAB>read1<TAB>read2
    S1<TAB>reads/S1_R1.fq.gz<TAB>reads/S1_R2.fq.gz
    S2<TAB>reads/S2_R1.fq.gz<TAB>reads/S2_R2.fq.gz

Output tree:
  <outdir>/00_inputs/samples.tsv
  <outdir>/00_inputs/samples.normalized.tsv
  <outdir>/00_inputs/input_files.tsv
  <outdir>/00_inputs/tx2gene.tsv
  <outdir>/01_logs/flow.log
  <outdir>/01_logs/steps/
  <outdir>/02_intermediate/trimmed/
  <outdir>/02_intermediate/tximport/
  <outdir>/03_results/fastqc/
  <outdir>/03_results/fastp/
  <outdir>/03_results/salmon/<sample>/quant.sf
  <outdir>/03_results/matrices/gene_counts.tsv
  <outdir>/03_results/matrices/gene_tpm.tsv
  <outdir>/03_results/matrices/gene_length.tsv
  <outdir>/03_results/matrices/transcript_counts.tsv
  <outdir>/03_results/matrices/transcript_tpm.tsv
  <outdir>/04_reports/multiqc_report.html
  <outdir>/04_reports/expression_summary.tsv
  <outdir>/04_reports/quant_files.tsv
  <outdir>/04_reports/commands.sh
  <outdir>/04_reports/versions.tsv
  <outdir>/04_reports/methods.txt
  <outdir>/04_reports/flow_summary.tsv
  <outdir>/run.manifest.json

Dependencies:
  taf-fastqc 0.12.1-r1
  taf-fastp 1.3.3-r3
  taf-salmon 1.11.4-r1
  taf-bioconductor-rnaseq 3.23-r1
  taf-multiqc 1.35-r2

Boundaries:
  r1 is Salmon-first and does not build indexes, run Kallisto quantification,
  perform differential expression, run genome alignment, run BAM-level RNA-seq
  QC, infer experimental design, or download reference data. It reads FASTQ
  files, a Salmon index, and tx2gene.tsv, writes only under <outdir>/, and does
  not modify input files or reference resources.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
