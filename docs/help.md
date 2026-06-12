rnaseq-expression-flow 0.2.0-r1

Purpose:
  Quantify bulk RNA-seq FASTQ samples against a prebuilt Salmon transcriptome
  index, then write per-sample quant.sf files, gene-level matrices,
  transcript-level matrices, MultiQC reports, logs, commands, versions,
  methods, and a manifest under one explicit output directory.

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

Key outputs:
  <outdir>/03_results/salmon/<sample>/quant.sf
      Per-sample Salmon quantification.

  <outdir>/03_results/matrices/gene_counts.tsv
      Gene-level count matrix for DE workflows.

  <outdir>/03_results/matrices/gene_tpm.tsv
      Gene-level TPM matrix.

  <outdir>/03_results/matrices/transcript_counts.tsv
      Transcript-level count matrix.

  <outdir>/04_reports/multiqc_report.html
      FASTQ/trim/quantification QC summary.

  <outdir>/04_reports/
      quant_files.tsv, expression_summary.tsv, commands.sh, versions.tsv,
      methods.txt, flow_summary.tsv, and provenance.

Upstream/downstream:
  Upstream:
    rnaseq-index-flow provides salmon_index and tx2gene.tsv.

  Downstream:
    rnaseq-de-flow can use gene_counts.tsv.
    rnaseq-report-flow can collect the expression output directory.

Advanced step passthrough:
  Optional expert slots for native tool parameters. They default to empty
  and are not needed for normal use.

  @fastqc-pe-step: ... @: FastQC for paired-end FASTQ.
  @fastqc-se-step: ... @: FastQC for single-end FASTQ.
  @fastp-pe-step: ... @: fastp paired-end trimming.
  @fastp-se-step: ... @: fastp single-end trimming.
  @salmon-quant-pe-step: ... @: salmon quant for paired-end samples.
  @salmon-quant-se-step: ... @: salmon quant for single-end samples.
  @tximport-step: ... @: rnaseq-tximport R wrapper.
  @salmon-quantmerge-counts-step: ... @: salmon quantmerge NumReads.
  @salmon-quantmerge-tpm-step: ... @: salmon quantmerge TPM.
  @multiqc-step: ... @: MultiQC report generation.

Sample table examples:
  Single-end:
    sample_id<TAB>read1
    S1<TAB>reads/S1.fq.gz
    S2<TAB>reads/S2.fq.gz

  Paired-end:
    sample_id<TAB>read1<TAB>read2
    S1<TAB>reads/S1_R1.fq.gz<TAB>reads/S1_R2.fq.gz
    S2<TAB>reads/S2_R1.fq.gz<TAB>reads/S2_R2.fq.gz

Boundaries:
  r1 is Salmon-first and does not build indexes, run Kallisto quantification,
  perform differential expression, run genome alignment, run BAM-level RNA-seq
  QC, infer experimental design, or download reference data. It reads FASTQ
  files, a Salmon index, and tx2gene.tsv, writes only under <outdir>/, and does
  not modify input files or reference resources.

Detailed documentation:
  https://github.com/taffish/rnaseq-expression-flow

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
