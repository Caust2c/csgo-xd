# Match-cluster bootstrap respects dependence among events in a demo.

#' Compute event-weighted regression metrics. R2 is undefined for constant targets.
regression_metrics <- function(y, pred) {
  err <- y - pred
  denom <- sum((y - mean(y))^2)
  c(MAE = mean(abs(err)), RMSE = sqrt(mean(err^2)),
    R2 = if (denom > 0) 1 - sum(err^2) / denom else NA_real_, Bias = mean(err))
}

#' Bootstrap test matches, including all sampled events of each resampled match.
#' Report paired improvement over the frozen weapon-hitbox training baseline.
cluster_validation <- function(d, pred, baseline, B = BOOTSTRAPS) {
  errors <- data.table::data.table(file = d$file, actual = d$total_damage,
    ae = abs(d$total_damage - pred), se = (d$total_damage - pred)^2,
    base_ae = abs(d$total_damage - baseline))
  agg <- errors[, .(n = .N, ae = sum(ae), se = sum(se), sy = sum(actual),
                    sy2 = sum(actual^2), improvement = sum(base_ae - ae)), by = file]
  if (nrow(agg) < 5L) stop('Need at least five held-out matches for statistical validation.')
  set.seed(SEED)
  draws <- replicate(B, {
    a <- agg[sample.int(nrow(agg), nrow(agg), replace = TRUE)]
    n <- sum(a$n)
    denom <- sum(a$sy2) - sum(a$sy)^2 / n
    c(MAE = sum(a$ae) / n, RMSE = sqrt(sum(a$se) / n),
      R2 = if (denom > 0) 1 - sum(a$se) / denom else NA_real_,
      improvement = sum(a$improvement) / n)
  })
  ci <- t(apply(draws, 1, stats::quantile, probs = c(.025, .975), na.rm = TRUE))
  # A match-level paired sign-flip randomization test, weighted by sampled row count.
  observed <- sum(agg$improvement) / sum(agg$n)
  null <- replicate(B, sum(agg$improvement * sample(c(-1, 1), nrow(agg), TRUE)) / sum(agg$n))
  list(ci = ci, improvement = observed,
       p_value = (1 + sum(abs(null) >= abs(observed))) / (B + 1), matches = nrow(agg))
}
