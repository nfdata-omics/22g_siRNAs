process MERGE_FEATURECOUNTS {
    tag "merge"
    label 'process_single'

    container 'quay.io/biocontainers/r-tidyverse:1.2.1'

    input:
    path counts  // collected list of .tsv files

    output:
    path "merged.featureCounts.tsv", emit: merged

    script:
    template 'merge_featurecounts.R'
}