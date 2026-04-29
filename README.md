# nfdata-omics/22g_sirnas

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/nfdata-omics/22g_sirnas)
[![GitHub Actions CI Status](https://github.com/nfdata-omics/22g_sirnas/actions/workflows/nf-test.yml/badge.svg)](https://github.com/nfdata-omics/22g_sirnas/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/nfdata-omics/22g_sirnas/actions/workflows/linting.yml/badge.svg)](https://github.com/nfdata-omics/22g_sirnas/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.4.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.4.1)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nfdata-omics/22g_sirnas)

## Introduction

**nfdata-omics/22g_sirnas** is a bioinformatics pipeline for identifying and quantifying 22G siRNAs from single-end Illumina FASTQ reads using a reference FASTA and GTF annotation. The workflow performs raw read QC, adapter trimming, quality filtering, optional UMI processing, enrichment of reads with the expected 5' G signature, alignment with Bowtie, and quantification with featureCounts. It produces cleaned intermediate read files, aligned BAM files, count tables, and consolidated QC and run reports through MultiQC and Nextflow pipeline metadata. This pipeline describes [[Almeida et al. 2019]](https://doi.org/10.1016/j.mex.2019.01.009) work.  

<!-- TODO nf-core: Include a figure that guides the user through the major workflow steps. Many nf-core
     workflows use the "tube map" design for that. See https://nf-co.re/docs/guidelines/graphic_design/workflow_diagrams#examples for examples.   -->
By default, the pipeline follows these steps:

1. Assess raw read quality with [`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).
2. Trim adapters and retain reads in the expected small RNA size range with [`cutadapt`](https://cutadapt.readthedocs.io/).
3. Re-assess trimmed reads with `FastQC`.
4. Filter reads by base quality using the custom [`FASTQ_QUALITY_FILTER`](modules/local/fastq_quallity_filter/main.nf) step.
5. Optionally process UMIs, trim UMI-derived bases, and run QC again when `--with_umi` is enabled using [`UMICollapse`](https://github.com/Daniel-Liu-c0deb0t/UMICollapse), [`seqtk`](https://github.com/lh3/seqtk), and [`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).
6. Select reads of exactly 22 nt with [`seqkit seq`](https://bioinf.shenwei.me/seqkit/usage/#seq).
7. Retain reads matching the expected 5' motif, by default `^G`, with [`seqkit grep`](https://bioinf.shenwei.me/seqkit/usage/#grep).
8. Build the [`Bowtie`](https://bowtie-bio.sourceforge.net/index.shtml) index from the provided reference FASTA.
9. Align filtered 22G reads to the reference with [`Bowtie`](https://bowtie-bio.sourceforge.net/index.shtml).
10. Quantify aligned reads against the provided annotation with [`featureCounts`](https://subread.sourceforge.net/featureCounts.html).
11. Collate QC metrics, logs, and software versions into a final [`MultiQC`](http://multiqc.info/) report.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with one row per sample and a header exactly matching the expected column names:

`samplesheet.csv`:

```csv
sample,fastq_1
CONTROL_REP1,/path/to/CONTROL_REP1.fastq.gz
CONTROL_REP2,/path/to/CONTROL_REP2.fastq.gz
```

The pipeline is single-end only and currently expects exactly one gzipped FASTQ file per sample.

| Column | Description |
| --- | --- |
| `sample` | Unique sample name without spaces. |
| `fastq_1` | Full path to the input FASTQ file ending in `.fastq.gz` or `.fq.gz`. |

Then run the pipeline with the samplesheet, an output directory, and either a configured `--genome` or both a reference FASTA and GTF annotation:

```bash
nextflow run nfdata-omics/22g_sirnas \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --fasta reference.fa \
   --gtf annotation.gtf \
   --outdir <OUTDIR>
```

To customise the 5' motif retained by `seqkit grep`, set `--grep_pattern`. The default is `^G`, which keeps reads starting with `G`.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Credits

nfdata-omics/22g_sirnas was originally written by Karla Alejandra Ruiz-Ceja.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nfdata-omics/22g_sirnas for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
