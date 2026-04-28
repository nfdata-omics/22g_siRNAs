process UMICOLLAPSE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/umicollapse:1.1.0--hdfd78af_0' :
        'quay.io/biocontainers/umicollapse:1.1.0--hdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*dedup*.fastq.gz"), emit: fastq
    tuple val(meta), path("*_UMICollapse.log"), emit: log
    tuple val("${task.process}"), val('umicollapse'), val('1.1.0'), emit: versions_umicollapse, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    umicollapse \\
        fastq \\
        -i ${reads} \\
        -o ${prefix}.dedup.fastq.gz \\
        ${args} \\
        2>&1 | tee ${prefix}_UMICollapse.log
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "UMI collapsing finished in 0 seconds" > ${prefix}_UMICollapse.log
    echo "Arguments [fastq, -i, ${reads}, -o, ${prefix}.dedup.fastq.gz]" >> ${prefix}_UMICollapse.log
    echo '' | gzip > ${prefix}.dedup.fastq.gz
    """
}
