process FASTQ_QUALITY_FILTER {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/1e/1e4dce7124230c2e3aa2782710246b68b7e5606a1fdafd29fe9d4aaffa2190a9/data' :
        'community.wave.seqera.io/library/fastx_toolkit:0.0.14--2d5a3f28610ed585' }"


    
    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.qf.fastq.gz"), emit: filtered_qc_reads
    path("*.qf_stats.txt")                , emit: filtered_qc_stats

    script:
    def prefix = "${meta.id}"
    def quality = params.quality_cutoff ?: 20
    def min_bases = params.min_quality_bases ?: 100
    def phred = params.phred_quality ?: 33
    """
    zcat ${reads} \\
    | fastq_quality_filter \\
        -q ${quality} \\
        -p ${min_bases} \\
        -Q ${phred} \\
        -o /dev/stdout \\
        2> ${prefix}.qf_stats.txt \\
    | gzip > ${prefix}.qf.fastq.gz
    """
}
