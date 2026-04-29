#!/usr/bin/env Rscript

metadata_cols <- c("Geneid", "Chr", "Start", "End", "Strand", "Length")

input_files <- list.files(".", pattern = "\\\\.tsv", full.names = TRUE)
if (length(input_files) == 0) stop("No featureCounts files found.", call. = FALSE)

read_fc <- function(path) {
    df <- read.delim(path, comment.char = "#", check.names = FALSE, stringsAsFactors = FALSE)
    if (ncol(df) < 7) stop(sprintf("Unexpected format: %s", path), call. = FALSE)
    sample_name <- sub("\\\\.featureCounts\\\\.tsv", "", basename(path))
    colnames(df)[ncol(df)] <- sample_name
    df[order(df\$Geneid), c(metadata_cols, sample_name)]
}

tables <- lapply(input_files, read_fc)

if (!all(sapply(tables[-1], function(t) all(t\$Geneid == tables[[1]]\$Geneid))))
    stop("Gene IDs do not match across files.", call. = FALSE)

merged <- Reduce(function(a, b) cbind(a, b[, ncol(b), drop = FALSE]), tables)

write.table(merged, "merged.featureCounts.tsv", sep = "\t", quote = FALSE, row.names = FALSE)