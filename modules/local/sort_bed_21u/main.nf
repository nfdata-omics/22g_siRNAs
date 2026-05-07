process SORT_BED_21U {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_0'
        : 'quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_0'}"

    input:
    tuple val(meta), path(bed)
    tuple val(meta2), path(fai)

    output:
    tuple val(meta), path("${prefix}.bed"), emit: bed
    tuple val("${task.process}"), val('bedtools'), eval("bedtools --version | sed -e 's/bedtools v//g'"), emit: versions_bedtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}.sorted"
    """
    bedtools sort \\
        -faidx ${fai} \\
        -i ${bed} \\
        > ${prefix}.bed
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}.sorted"
    """
    touch ${prefix}.bed
    """
}
