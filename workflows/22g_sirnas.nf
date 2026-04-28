/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_TRIM       } from '../modules/nf-core/fastqc/main'
include { CUTADAPT                    } from '../modules/nf-core/cutadapt/main'
include { FASTQ_QUALITY_FILTER        } from '../modules/local/fastq_quallity_filter/main'
include { UMIS_TRIM_FASTQC            } from '../subworkflows/local/umis_trim_fastqc/main'
include { SEQKIT_SEQ                  } from '../modules/nf-core/seqkit/seq/main'
include { SEQKIT_GREP                 } from '../modules/nf-core/seqkit/grep/main'
include { BOWTIE_BUILD                } from '../modules/nf-core/bowtie/build/main'
include { BOWTIE_ALIGN                } from '../modules/nf-core/bowtie/align/main'
include { SUBREAD_FEATURECOUNTS       } from '../modules/nf-core/subread/featurecounts/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_22g_sirnas_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NF_22G_SIRNAS {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_final_reads = Channel.empty()
    ch_22g_reads = Channel.empty()
    ch_aligned_bam = Channel.empty()
    ch_reference_fasta = Channel.value([
        [id: 'reference'],
        file(params.fasta, checkIfExists: true)
    ])
    ch_annotation = Channel.value(file(params.gtf, checkIfExists: true))
    ch_g_start_pattern = Channel.fromPath(
        "$projectDir/assets/seqkit_g_start_pattern.txt", checkIfExists: true
    )

    //
    // MODULE: Run FastQC on raw reads
    //
    FASTQC (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { it[1] })
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // MODULE: filter by size
    //
    CUTADAPT (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(CUTADAPT.out.log.collect { it[1] })
    ch_versions = ch_versions.mix(CUTADAPT.out.versions_cutadapt)

    //
    // FASTQC TRIM
    //
    FASTQC_TRIM(
            CUTADAPT.out.reads
        )
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC_TRIM.out.zip.collect{ it[1] })

    //
    // MODULE: Filter reads by base quality after adapter removal
    //
    FASTQ_QUALITY_FILTER (
        CUTADAPT.out.reads
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQ_QUALITY_FILTER.out.filtered_qc_stats)

    if (params.with_umi) {
        UMIS_TRIM_FASTQC (
            FASTQ_QUALITY_FILTER.out.filtered_qc_reads
        )
        ch_final_reads = UMIS_TRIM_FASTQC.out.reads
        ch_multiqc_files = ch_multiqc_files.mix(UMIS_TRIM_FASTQC.out.multiqc_files)
        ch_versions = ch_versions.mix(UMIS_TRIM_FASTQC.out.versions)
    } else {
        ch_final_reads = FASTQ_QUALITY_FILTER.out.filtered_qc_reads
    }

    SEQKIT_SEQ(
        ch_final_reads
    )
    ch_versions = ch_versions.mix(SEQKIT_SEQ.out.versions_seqkit)

    SEQKIT_GREP(
        SEQKIT_SEQ.out.fastx,
        ch_g_start_pattern
    )
    ch_versions = ch_versions.mix(SEQKIT_GREP.out.versions_seqkit)
    ch_22g_reads = SEQKIT_GREP.out.filter.filter { meta, reads ->
        def has_reads = fileHasContent(reads)
        if (!has_reads) {
            log.warn "Skipping BOWTIE_ALIGN for ${meta.id}: no reads remained after G-start filtering"
        }
        return has_reads
    }

    BOWTIE_BUILD(
        ch_reference_fasta
    )
    ch_versions = ch_versions.mix(BOWTIE_BUILD.out.versions_bowtie)

    BOWTIE_ALIGN(
        ch_22g_reads,
        BOWTIE_BUILD.out.index.first(),
        false
    )
    ch_versions = ch_versions.mix(BOWTIE_ALIGN.out.versions_bowtie)
    ch_versions = ch_versions.mix(BOWTIE_ALIGN.out.versions_samtools)
    ch_versions = ch_versions.mix(BOWTIE_ALIGN.out.versions_gzip)
    ch_multiqc_files = ch_multiqc_files.mix(BOWTIE_ALIGN.out.log.collect { it[1] })
    ch_aligned_bam = BOWTIE_ALIGN.out.bam

    SUBREAD_FEATURECOUNTS(
        ch_aligned_bam
            .combine(ch_annotation)
            .map { meta, bam, annotation -> [ meta + [ strandedness: 'reverse' ], bam, annotation ] }
    )
    ch_versions = ch_versions.mix(SUBREAD_FEATURECOUNTS.out.versions_subread)
    ch_multiqc_files = ch_multiqc_files.mix(SUBREAD_FEATURECOUNTS.out.counts.collect { it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(SUBREAD_FEATURECOUNTS.out.summary.collect { it[1] })

    //
    // Collate and save software versions
    //
    ch_versions
        .map { version -> normaliseVersionRecord(version) }
        .set { ch_normalised_versions }

    softwareVersionsToYAML(ch_normalised_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  '22g_sirnas_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    trimmed_reads = CUTADAPT.out.reads
    cutadapt_log = CUTADAPT.out.log
    filtered_reads = FASTQ_QUALITY_FILTER.out.filtered_qc_reads
    filtered_qc_stats = FASTQ_QUALITY_FILTER.out.filtered_qc_stats
    umi_processed_reads = ch_final_reads
    final_reads = ch_22g_reads
    aligned_bam = ch_aligned_bam
    bowtie_log = BOWTIE_ALIGN.out.log
    featurecounts = SUBREAD_FEATURECOUNTS.out.counts
    featurecounts_summary = SUBREAD_FEATURECOUNTS.out.summary
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def normaliseVersionRecord(version) {
    if (version instanceof List && version.size() == 3) {
        def (process_name, tool_name, tool_version) = version
        return """
        ${process_name}:
            ${tool_name}: ${tool_version}
        """.stripIndent().trim()
    }

    if (version instanceof java.nio.file.Path) {
        return version.toFile().text
    }

    return version.toString()
}

def fileHasContent(path) {
    def stream = null
    try {
        stream = path.toString().endsWith('.gz')
            ? new java.util.zip.GZIPInputStream(new java.io.FileInputStream(path.toFile()))
            : new java.io.FileInputStream(path.toFile())
        return stream.read() != -1
    } finally {
        stream?.close()
    }
}
