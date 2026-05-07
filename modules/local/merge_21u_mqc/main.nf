process MERGE_21U_MQC {
    tag "merge_21u_multiqc"
    label 'process_low'

    container 'quay.io/biocontainers/mulled-v2-0560a8046fc82aa4338588eca29ff18edab2c5aa:a5d29a3763e96bdce12142816d06b607a8d00eeb-0'

    input:
    path(length_files, stageAs: 'lengths/*')
    path(first_nt_files, stageAs: 'first_nt/*')

    output:
    tuple val('21u_read_lengths'), path("21u_read_lengths.tsv")     , emit: summary_lengths
    tuple val('21u_first_nt'), path("21u_first_nt.tsv")             , emit: summary_nt

    script:
    """
    merge_mqc() {
        local mode="\$1"
        local output="\$2"
        local key_header
        local files=()

        if [[ "\$mode" == "length" ]]; then
            key_header="length"
            while IFS= read -r file; do
                files+=("\$file")
            done < <(find -L lengths -type f -name '*.21u_read_lengths.tsv' | sort)
            {
                echo "#id: '21u_read_lengths'"
                echo "#section_name: '21U Read Length Distribution'"
                echo "#description: 'Read length distribution of reads overlapping 21U-RNA loci'"
            } > "\$output"
            keys=\$(awk 'BEGIN{FS="\\t"} !/^#/ && \$1 != "length" { print \$1 }' "\${files[@]}" | sort -n | uniq)
        else
            key_header="nucleotide"
            while IFS= read -r file; do
                files+=("\$file")
            done < <(find -L first_nt -type f -name '*.21u_first_nt.tsv' | sort)
            {
                echo "#id: '21u_first_nt'"
                echo "#section_name: '21U 5'' Nucleotide Frequency'"
                echo "#description: 'Frequency of the 5'' nucleotide of reads overlapping 21U-RNA loci'"
            } > "\$output"
            keys=\$(awk 'BEGIN{FS="\\t"} !/^#/ && \$1 != "nucleotide" { print \$1 }' "\${files[@]}" | sort | uniq)
        fi

        if [[ \${#files[@]} -eq 0 ]]; then
            echo "No input files found for mode: \$mode" >&2
            return 1
        fi

        {
            printf "%s" "\$key_header"
            for f in "\${files[@]}"; do
                sample=\$(awk 'BEGIN{FS="\\t"} !/^#/ { print \$2; exit }' "\$f")
                printf "\\t%s" "\$sample"
            done
            printf "\\n"

            while IFS= read -r key; do
                [[ -z "\$key" ]] && continue
                printf "%s" "\$key"
                for f in "\${files[@]}"; do
                    value=\$(awk -v key="\$key" 'BEGIN{FS="\\t"} !/^#/ && \$1 == key { print \$2; exit }' "\$f")
                    printf "\\t%s" "\$value"
                done
                printf "\\n"
            done <<< "\$keys"
        } >> "\$output"
    }

    merge_mqc length 21u_read_lengths.tsv
    merge_mqc first_nt 21u_first_nt.tsv
    """
}
