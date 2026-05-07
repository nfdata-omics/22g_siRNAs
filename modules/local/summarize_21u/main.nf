process SUMMARIZE_21U {
    tag "$meta.id"
    label 'process_single'

    container 'quay.io/biocontainers/mulled-v2-0560a8046fc82aa4338588eca29ff18edab2c5aa:a5d29a3763e96bdce12142816d06b607a8d00eeb-0'
    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.21u_read_lengths.tsv"), emit: read_lengths
    tuple val(meta), path("*.21u_first_nt.tsv")    , emit: first_nt
    path "versions.yml"                            , emit: versions

    script:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
     {
        # Read length distribution — MultiQC custom content header
        echo "#id: '21u_read_lengths'"
        echo "#section_name: '21U Read Length Distribution'"
        echo "#description: 'Read length distribution of reads overlapping 21U-RNA loci'"
        echo -e "length\t${prefix}"
        samtools view ${bam} | awk '
            { len[length(\$10)]++ }
            END {
                for (l in len)
                    print l"\t"len[l]
            }
        ' | sort -k1,1n

    } > ${prefix}.21u_read_lengths.tsv

    {
        # 5-prime nucleotide frequency — MultiQC custom content header
        echo "#id: '21u_first_nt'"
        echo "#section_name: '21U 5'' Nucleotide Frequency'"
        echo "#description: 'Frequency of the 5'' nucleotide of reads overlapping 21U-RNA loci'"
        echo -e "nucleotide\t${prefix}"
        samtools view ${bam} | awk '
            { nt[substr(\$10,1,1)]++ }
            END {
                for (n in nt)
                    print n"\t"nt[n]
            }
        ' | sort -k1,1

    } > ${prefix}.21u_first_nt.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools version | head -1 | sed 's/samtools //')
    END_VERSIONS
    """
}
