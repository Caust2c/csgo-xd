# Train-only encoding, filtering, and scaling shared by every algorithm.

#' Fit preprocessing on the actual training subset, never validation or test.
fit_preprocessor <- function(d) {
  levels <- setNames(lapply(CAT_FEATURES, function(col) {
    counts <- sort(table(as.character(d[[col]])), decreasing = TRUE)
    head(names(counts), 25L)
  }), CAT_FEATURES)
  pre <- list(levels = levels, numeric = NUMERIC_FEATURES)
  x <- raw_matrix(d, pre)
  sd_x <- apply(x, 2, stats::sd)
  keep <- names(sd_x)[is.finite(sd_x) & sd_x > 1e-8]
  # Remove redundant numeric features at |r| > .98; no outcome information is used.
  numeric_keep <- intersect(NUMERIC_FEATURES, keep)
  removed <- character()
  if (length(numeric_keep) > 1L) {
    correlations <- stats::cor(x[, numeric_keep, drop = FALSE])
    for (j in seq_along(numeric_keep)[-1]) {
      earlier <- setdiff(numeric_keep[seq_len(j - 1L)], removed)
      if (any(abs(correlations[numeric_keep[j], earlier]) > .98))
        removed <- c(removed, numeric_keep[j])
    }
  }
  pre$keep <- setdiff(keep, removed)
  pre$center <- colMeans(x[, pre$keep, drop = FALSE])
  pre$scale <- apply(x[, pre$keep, drop = FALSE], 2, stats::sd)
  pre$dropped <- setdiff(colnames(x), pre$keep)
  pre
}

#' Explicit one-hot encoding: unknown/rare categories are the all-zero reference.
raw_matrix <- function(d, pre) {
  numeric <- as.matrix(as.data.frame(d)[, pre$numeric, drop = FALSE])
  storage.mode(numeric) <- 'double'
  parts <- lapply(names(pre$levels), function(col) {
    lv <- pre$levels[[col]]
    # One level is omitted to avoid the dummy-variable trap in linear models.
    lv <- if (length(lv) > 1L) lv[-1L] else character()
    if (!length(lv)) return(NULL)
    block <- vapply(lv, function(level) as.numeric(as.character(d[[col]]) == level),
                    numeric(nrow(d)))
    if (is.null(dim(block))) block <- matrix(block, ncol = 1L)
    colnames(block) <- make.names(paste(col, lv, sep = '__'), unique = TRUE)
    block
  })
  out <- do.call(cbind, c(list(numeric), parts))
  out[!is.finite(out)] <- 0
  out
}

#' Apply frozen preprocessing; models receive identical scaled feature matrices.
transform_features <- function(d, pre) {
  x <- raw_matrix(d, pre)[, pre$keep, drop = FALSE]
  x <- sweep(sweep(x, 2, pre$center, '-'), 2, pre$scale, '/')
  colnames(x) <- make.names(colnames(x), unique = TRUE)
  x
}
