# Bounded sample -> match splits -> train-only preprocessing -> 12 methods -> test.
source('config.R')
check_packages()
suppressPackageStartupMessages(library(data.table))
setDTthreads(THREADS)
source(file.path(PROJECT_ROOT, 'R', 'preprocess.R'))
source(file.path(PROJECT_ROOT, 'R', 'models.R'))
source(file.path(PROJECT_ROOT, 'R', 'statistics.R'))

#' Retrieve a map-balanced, capped sample from SQLite via parameterized SQL.
#' Per-match deterministic pseudo-random ordering avoids taking only early rounds.
load_sample <- function() {
  if (!file.exists(DB_PATH)) stop('Run database.R first.')
  con <- DBI::dbConnect(RSQLite::SQLite(), DB_PATH)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  matches <- as.data.table(DBI::dbGetQuery(con, 'SELECT file, map, COUNT(*) AS n FROM events GROUP BY file, map ORDER BY map, file'))
  if (nrow(matches) < 30L) stop('Need at least 30 usable matches; increase smoke CHUNK_ROWS.')
  set.seed(SEED)
  matches <- matches[sample.int(.N)]
  # Round robin across maps; maps with few matches exhaust their supply naturally.
  matches[, map_order := seq_len(.N), by = map]
  setorder(matches, map_order, map, file)
  max_matches <- max(30L, ceiling(SAMPLE_ROWS / MAX_PER_MATCH))
  matches <- head(matches, max_matches)
  # Split within each map where possible; tiny maps receive a reproducible global split.
  matches[, split := {
    n <- .N
    if (n >= 3L) {
      nv <- max(1L, floor(n * .15)); nt <- max(1L, floor(n * .15))
      sample(c(rep('train', n - nv - nt), rep('validation', nv), rep('test', nt)))
    } else sample(c('train', 'validation', 'test'), n, replace = TRUE, prob = c(.7, .15, .15))
  }, by = map]
  data.table::fwrite(matches, file.path(OUTPUT_DIR, 'match_splits.csv'))
  rows <- lapply(seq_len(nrow(matches)), function(i) {
    limit <- min(MAX_PER_MATCH, floor(SAMPLE_ROWS / nrow(matches)))
    part <- as.data.table(DBI::dbGetQuery(con,
      'SELECT * FROM events WHERE file=? ORDER BY ((tick * 1103515245 + round * 12345) % 2147483647), rowid LIMIT ?',
      params = list(matches$file[i], limit)))
    part[, split := matches$split[i]]
    part
  })
  d <- rbindlist(rows)
  if (any(table(factor(d$split, levels = c('train', 'validation', 'test'))) == 0L)) stop('An empty partition was produced.')
  if (uniqueN(d[split == 'test', file]) < 5L) stop('Too few test matches. Increase SAMPLE_ROWS / CHUNK_ROWS.')
  stopifnot(nrow(d) <= SAMPLE_ROWS,
    !length(intersect(d[split == 'train', file], d[split == 'test', file])),
    !length(intersect(d[split == 'train', file], d[split == 'validation', file])),
    !length(intersect(d[split == 'validation', file], d[split == 'test', file])))
  d
}

#' Fit a weapon-hitbox mean baseline on training only; unseen pairs use global mean.
fit_baseline <- function(d) {
  groups <- d[, .(baseline = mean(total_damage)), by = .(wp, hitbox)]
  keys <- paste(groups$wp, groups$hitbox, sep = '|')
  values <- setNames(groups$baseline, keys)
  fallback <- mean(d$total_damage)
  function(z) {
    pred <- unname(values[paste(z$wp, z$hitbox, sep = '|')])
    pred[is.na(pred)] <- fallback
    pred
  }
}

run_pipeline <- function() {
  set.seed(SEED)
  d <- load_sample()
  saveRDS(d, file.path(MODEL_DIR, 'analysis_sample.rds'))
  train <- d[split == 'train']
  train <- train[sample.int(.N, min(.N, FIT_ROWS))]
  val <- d[split == 'validation']
  test <- d[split == 'test']
  pre <- fit_preprocessor(train)
  saveRDS(pre, file.path(MODEL_DIR, 'preprocessor.rds'))
  fwrite(data.table(feature = pre$keep, center = pre$center, scale = pre$scale),
         file.path(OUTPUT_DIR, 'selected_features.csv'))
  writeLines(pre$dropped, file.path(OUTPUT_DIR, 'dropped_features.txt'))
  x <- transform_features(train, pre)
  xv <- transform_features(val, pre)
  xt <- transform_features(test, pre)
  base <- fit_baseline(train)
  baseline_test <- base(test)
  baseline_val <- base(val)
  test_export <- test[, .(file, map, round, tick, actual = total_damage)]
  test_export[, WeaponHitboxBaseline := baseline_test]
  val_scores <- list(WeaponHitboxBaseline = mean(abs(val$total_damage - baseline_val)))
  model_results <- list()
  status <- list()
  predictions_dir <- file.path(MODEL_DIR, 'predictions')
  dir.create(predictions_dir, showWarnings = FALSE)
  # Remove prior prediction caches so skipped models cannot leave stale heatmaps.
  old <- list.files(predictions_dir, '\\.rds$', full.names = TRUE)
  if (length(old)) unlink(old)
  for (name in ALGORITHMS) {
    message('Fitting ', name)
    set.seed(SEED)
    started <- proc.time()[['elapsed']]
    result <- tryCatch({
      model <- fit_algorithm(name, x, train$total_damage, xv, val$total_damage)
      pv <- model$predict(xv)
      pt <- model$predict(xt)
      if (length(pt) != nrow(test) || any(!is.finite(pt)) || any(!is.finite(pv))) stop('Nonfinite predictions.')
      val_scores[[name]] <- mean(abs(val$total_damage - pv))
      test_export[, (name) := pt]
      metrics <- regression_metrics(test$total_damage, pt)
      stats <- cluster_validation(test, pt, baseline_test)
      model_results[[name]] <- data.table(model = name, validation_MAE = val_scores[[name]],
        MAE = metrics['MAE'], RMSE = metrics['RMSE'], R2 = metrics['R2'], Bias = metrics['Bias'],
        MAE_lower = stats$ci['MAE', 1], MAE_upper = stats$ci['MAE', 2],
        RMSE_lower = stats$ci['RMSE', 1], RMSE_upper = stats$ci['RMSE', 2],
        R2_lower = stats$ci['R2', 1], R2_upper = stats$ci['R2', 2],
        MAE_improvement = stats$improvement,
        improvement_lower = stats$ci['improvement', 1], improvement_upper = stats$ci['improvement', 2],
        p_value = stats$p_value, test_matches = stats$matches)
      # Heatmaps use held-out matches exclusively; never training residuals.
      cache <- copy(test[, .(file, map, att_pos_x, att_pos_y, total_damage)])
      cache[, `:=`(expected_damage = pt, xd_difference = total_damage - pt)]
      saveRDS(cache, file.path(predictions_dir, paste0(name, '.rds')))
      saveRDS(model, file.path(MODEL_DIR, paste0(name, '.rds')))
      # Portable XGBoost serialization supplements RDS.
      if (name == 'XGBoost') xgboost::xgb.save(model$object, file.path(MODEL_DIR, 'xd_model.json'))
      jsonlite::write_json(model$tuning, file.path(MODEL_DIR, paste0(name, '_tuning.json')),
                           auto_unbox = TRUE, pretty = TRUE)
      rm(model, cache)
      'ok'
    }, error = function(e) paste('failed:', conditionMessage(e)))
    if (result != 'ok') {
      # Do not count partially completed fits or leave stale prediction caches.
      model_results[[name]] <- NULL
      val_scores[[name]] <- NULL
      if (name %in% names(test_export)) test_export[, (name) := NULL]
      partial <- c(file.path(predictions_dir, paste0(name, '.rds')),
                   file.path(MODEL_DIR, paste0(name, '.rds')))
      unlink(partial[file.exists(partial)])
    }
    status[[name]] <- data.table(model = name, status = result,
                                  seconds = proc.time()[['elapsed']] - started)
    gc(verbose = FALSE)
  }
  fwrite(rbindlist(status), file.path(OUTPUT_DIR, 'model_status.csv'))
  if (!length(model_results)) stop('All algorithms failed. Inspect output/model_status.csv.')
  results <- rbindlist(model_results)
  results[, p_holm := p.adjust(p_value, method = 'holm')]
  # Winner selected by validation only, with baseline eligible to win.
  winner <- names(which.min(unlist(val_scores)))
  results[, selected_by_validation := model == winner]
  fwrite(results, file.path(OUTPUT_DIR, 'model_comparison.csv'))
  fwrite(test_export, file.path(OUTPUT_DIR, 'test_predictions.csv'))
  base_metrics <- regression_metrics(test$total_damage, baseline_test)
  jsonlite::write_json(list(model = 'WeaponHitboxBaseline', metrics = as.list(base_metrics),
    validation_MAE = val_scores[['WeaponHitboxBaseline']]),
    file.path(OUTPUT_DIR, 'baseline_metrics.json'), auto_unbox = TRUE, pretty = TRUE)
  writeLines(winner, file.path(OUTPUT_DIR, 'selected_model.txt'))
  if (winner == 'WeaponHitboxBaseline') saveRDS(base, file.path(MODEL_DIR, 'WeaponHitboxBaseline.rds'))
  cache <- copy(test[, .(file, map, att_pos_x, att_pos_y, total_damage)])
  cache[, `:=`(expected_damage = baseline_test, xd_difference = total_damage - baseline_test)]
  saveRDS(cache, file.path(predictions_dir, 'WeaponHitboxBaseline.rds'))
  # Permutation importance uses validation data and freezes the selected model.
  if (winner != 'WeaponHitboxBaseline') {
    best <- readRDS(file.path(MODEL_DIR, paste0(winner, '.rds')))
    set.seed(SEED)
    importance <- vapply(seq_len(ncol(xv)), function(j) {
      z <- xv
      z[, j] <- sample(z[, j])
      mean(abs(val$total_damage - best$predict(z))) - val_scores[[winner]]
    }, numeric(1))
    fwrite(data.table(feature = colnames(xv), validation_MAE_increase = importance),
           file.path(OUTPUT_DIR, 'permutation_importance.csv'))
  }
  manifest <- list(seed = SEED, smoke = SMOKE, rows = nrow(d), fit_rows = nrow(train),
    validation_rows = nrow(val), test_rows = nrow(test), test_matches = uniqueN(test$file),
    successful_algorithms = nrow(results), requested_algorithms = length(ALGORITHMS),
    selected_model = winner, sample_policy = 'map-balanced matches; capped pseudo-random rows per match',
    database = DB_PATH, bootstrap_replicates = BOOTSTRAPS, threads = THREADS,
    R = R.version.string, platform = R.version$platform,
    packages = as.list(setNames(vapply(REQUIRED_PACKAGES, function(p)
      as.character(utils::packageVersion(p)), character(1)), REQUIRED_PACKAGES)))
  jsonlite::write_json(manifest, file.path(OUTPUT_DIR, 'run_manifest.json'),
                       auto_unbox = TRUE, pretty = TRUE)
  capture.output(sessionInfo(), file = file.path(OUTPUT_DIR, 'sessionInfo.txt'))
  if (nrow(results) < 10L) warning('Fewer than 10 algorithms succeeded. Resolve model_status.csv failures before submission.')
  message('Validation-selected model: ', winner, '; successful algorithms: ', nrow(results))
  invisible(results)
}
run_pipeline()
