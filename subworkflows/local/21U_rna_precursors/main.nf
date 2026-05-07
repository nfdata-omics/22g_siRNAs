/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { BEDTOOLS_INTERSECT    as BEDTOOLS_INTERSECT_21U      } from '../../../modules/nf-core/bedtools/intersect/main'
include { SAMTOOLS_FAIDX        as SAMTOOLS_FAIDX_21U          } from '../../../modules/nf-core/samtools/faidx/main'
include { SAMTOOLS_SORT         as SAMTOOLS_SORT_21U           } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX        as SAMTOOLS_INDEX_21U_SORTED   } from '../../../modules/nf-core/samtools/index/main'
include { SUMMARIZE_21U                                        } from '../../../modules/local/summarize_21u'
include { MERGE_21U_MQC                                        } from '../../../modules/local/merge_21u_mqc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RNA_21U_PRECURSORS {
    take:
    bam
    fasta
    annotated_21u_loci

    main:
    ch_versions = Channel.empty()

    SAMTOOLS_FAIDX_21U(
        fasta
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX_21U.out.versions_samtools)

    SAMTOOLS_SORT_21U(
        bam,
        SAMTOOLS_FAIDX_21U.out.fasta_fai,
        ''
    )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT_21U.out.versions_samtools)

    SAMTOOLS_INDEX_21U_SORTED(
        SAMTOOLS_SORT_21U.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX_21U_SORTED.out.versions_samtools)

    BEDTOOLS_INTERSECT_21U(
        SAMTOOLS_SORT_21U.out.bam
            .combine(annotated_21u_loci)
            .map { meta, sorted_bam, loci_meta, loci_bed ->
                [meta, sorted_bam, loci_bed]
            },
        SAMTOOLS_FAIDX_21U.out.fasta_fai.map { meta, reference, fai ->
            [meta, fai]
        }
    )
    ch_versions = ch_versions.mix(BEDTOOLS_INTERSECT_21U.out.versions_bedtools)

    SUMMARIZE_21U(BEDTOOLS_INTERSECT_21U.out.intersect)
    ch_versions = ch_versions.mix(SUMMARIZE_21U.out.versions)

    MERGE_21U_MQC(
        SUMMARIZE_21U.out.read_lengths.map { meta, file -> file }.collect(),
        SUMMARIZE_21U.out.first_nt.map { meta, file -> file }.collect()
    )

    emit:
    fasta_fai           = SAMTOOLS_FAIDX_21U.out.fasta_fai
    sorted_bam          = SAMTOOLS_SORT_21U.out.bam
    sorted_bam_index    = SAMTOOLS_INDEX_21U_SORTED.out.index
    summary             = MERGE_21U_MQC.out.summary_lengths.mix(MERGE_21U_MQC.out.summary_nt)
    versions            = ch_versions
}
