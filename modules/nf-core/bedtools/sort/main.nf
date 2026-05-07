process BEDTOOLS_SORT {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_0'
        : 'quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_0'}"

    input:
    tuple val(meta), path(intervals)
    tuple val(meta2), path(chrom_sizes)

    output:
    tuple val(meta), path("*.bed"), emit: bed
    tuple val("${task.process}"), val('bedtools'), eval("bedtools --version | sed -e 's/bedtools v//g'"), topic: versions, emit: versions_bedtools

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.sorted"
    extension = task.ext.suffix ?: "bed"
    def faidx = chrom_sizes ? "-faidx ${chrom_sizes}" : ''
    if ("${intervals}" == "${prefix}.${extension}") {
        error("Input and output names are the same, use \"task.ext.prefix\" to disambiguate!")
    }
    """
    bedtools \\
        sort \\
        ${args} \\
        ${faidx} \\
        -i ${intervals} \\
        > ${prefix}.${extension}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.sorted"
    extension = task.ext.suffix ?: "bed"
    """
    touch ${prefix}.${extension}
    """
}
