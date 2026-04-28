/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { UMICOLLAPSE                  } from '../../../modules/local/umicollapse/main'
include { SEQTK_TRIM                   } from '../../../modules/nf-core/seqtk/trim/main'
include { FASTQC as FASTQC_UMI         } from '../../../modules/nf-core/fastqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UMIS_TRIM_FASTQC {

    take:
    ch_reads

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    UMICOLLAPSE(
        ch_reads
    )
    ch_versions = ch_versions.mix(UMICOLLAPSE.out.versions_umicollapse)
    ch_multiqc_files = ch_multiqc_files.mix(UMICOLLAPSE.out.log.collect { it[1] })

    SEQTK_TRIM(
        UMICOLLAPSE.out.fastq
    )
    ch_versions = ch_versions.mix(SEQTK_TRIM.out.versions_seqtk)

    FASTQC_UMI(
        SEQTK_TRIM.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC_UMI.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_UMI.out.zip.collect { it[1] })

    emit:
    reads = SEQTK_TRIM.out.reads
    umicollapse_log = UMICOLLAPSE.out.log
    fastqc_html = FASTQC_UMI.out.html
    fastqc_zip = FASTQC_UMI.out.zip
    multiqc_files = ch_multiqc_files
    versions = ch_versions
}
