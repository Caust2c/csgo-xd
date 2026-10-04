# Meaningful post-run checks: leakage, exported metrics, and saved model equivalence.
# Run in the same CSGO_SMOKE mode as the artifacts being checked.
source('config.R')
check_packages()
source('R/preprocess.R')
source('R/statistics.R')
suppressPackageStartupMessages(library(data.table))
manifest <- jsonlite::fromJSON(file.path(OUTPUT_DIR, 'run_manifest.json'))
stopifnot(identical(manifest$smoke, SMOKE))
d <- as.data.table(readRDS(file.path(MODEL_DIR, 'analysis_sample.rds')))
split_files <- lapply(c('train', 'validation', 'test'), function(s) unique(d[split == s, file]))
stopifnot(!length(intersect(split_files[[1]], split_files[[2]])),
          !length(intersect(split_files[[1]], split_files[[3]])),
          !length(intersect(split_files[[2]], split_files[[3]])))
pre <- readRDS(file.path(MODEL_DIR, 'preprocessor.rds'))
stopifnot(!any(grepl('hp_dmg|arm_dmg|total_damage|att_id|vic_id', pre$keep)))
predictions <- fread(file.path(OUTPUT_DIR, 'test_predictions.csv'))
results <- fread(file.path(OUTPUT_DIR, 'model_comparison.csv'))
status <- fread(file.path(OUTPUT_DIR, 'model_status.csv'))
test <- d[split == 'test']
stopifnot(nrow(test) == nrow(predictions),
          identical(as.character(test$file), as.character(predictions$file)),
          isTRUE(all.equal(test$total_damage, predictions$actual)), nrow(results) >= 10L)
check_rows <- seq_len(min(100L, nrow(test)))
z <- transform_features(test[check_rows], pre)
for (name in results$model) {
  pred <- predictions[[name]]
  stopifnot(all(is.finite(pred)))
  metrics <- regression_metrics(predictions$actual, pred)
  r <- results[model == name]
  stopifnot(abs(metrics['MAE'] - r$MAE) < 1e-8,
            abs(metrics['RMSE'] - r$RMSE) < 1e-8,
            r$MAE_lower <= r$MAE_upper, r$p_holm >= r$p_value)
  model <- readRDS(file.path(MODEL_DIR, paste0(name, '.rds')))
  reloaded <- model$predict(z)
  stopifnot(isTRUE(all.equal(as.numeric(reloaded), as.numeric(pred[check_rows]), tolerance = 1e-6)))
  message('Verified exported metrics and model reload: ', name)
  rm(model)
  gc(verbose = FALSE)
}
support <- fread(file.path(OUTPUT_DIR, 'heatmap_support.csv'))
stopifnot(all(support$outside_bounds >= 0), all(support$outside_bounds <= support$events))
grids <- list.files(file.path(OUTPUT_DIR, 'heatmaps', results$model[1]), '_grid[.]csv$', full.names = TRUE)
for (path in grids) {
  grid <- fread(path)
  stopifnot(all(grid$matches <= grid$events), all(grid$events > 0))
}
report <- c('Post-run verification passed.',
  paste('Mode:', if (SMOKE) 'smoke' else 'production'),
  paste('Saved models checked:', nrow(results)),
  'Checked match partition disjointness, excluded outcome features, finite predictions,',
  'independently recomputed metrics, interval order, adjusted p-values,',
  'fresh model reload predictions and spatial support invariants.')
writeLines(report, file.path(OUTPUT_DIR, 'verification.txt'))
message(paste(report, collapse = '\n'))
