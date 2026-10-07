# DA2 demonstration helpers. Open csgo_xD.Rproj, then source this file.
# These functions do not retrain models or replace production results.

demo_root <- normalizePath(getwd(), winslash = '/', mustWork = TRUE)
if (!file.exists(file.path(demo_root, 'csgo_xD.Rproj')))
  stop('Open csgo_xD.Rproj before sourcing presentation/live_demo.R.')
if (dir.exists('.R-library')) .libPaths(c(normalizePath('.R-library'), .libPaths()))

#' Check packages and distinguish the committed snapshot from local run artifacts.
demo_preflight <- function() {
  pkgs <- c('data.table', 'DBI', 'RSQLite', 'readr', 'ggplot2', 'dplyr',
            'tidyr', 'glmnet', 'ranger', 'gbm', 'earth', 'png', 'jsonlite',
            'plotly', 'htmlwidgets', 'nnet', 'mgcv', 'rpart', 'xgboost')
  # Inspect installed packages without loading all nineteen native DLLs at once.
  installed <- utils::installed.packages()
  index <- match(pkgs, installed[, 'Package'])
  available <- !is.na(index)
  versions <- rep('MISSING', length(pkgs))
  versions[available] <- installed[index[available], 'Version']
  print(data.frame(package = pkgs, version = versions), row.names = FALSE)
  cat('\nR:', R.version.string, '\nWorking directory:', demo_root, '\n')
  cat('Snapshot gallery:', file.exists('results/index.html'), '\n')
  cat('Local production database:', file.exists('database/csgo.sqlite'), '\n')
  cat('Local prediction artifacts:', all(file.exists(c('models/xd_model.json',
    'models/analysis_sample.rds', 'models/preprocessor.rds'))), '\n')
  if (any(!available)) cat('Before class, run source("00_install_packages.R").\n')
  invisible(data.frame(package = pkgs, available, version = versions))
}

#' Connect to the production SQLite database read-only and retrieve actual rows.
demo_database <- function(isolate = .Platform$OS.type == 'windows') {
  path <- file.path(demo_root, 'database', 'csgo.sqlite')
  if (!file.exists(path)) stop('Local database missing. Prepare production before class; the GitHub snapshot does not include it.')
  if (isTRUE(isolate)) {
    # Keep a native SQLite backend in a separate R process on Windows.
    # This local RSQLite build can fail during process shutdown, after returning
    # valid rows. The presenter R session must remain usable for live inference.
    settings <- tempfile('csgo-sql-settings-', fileext = '.rds')
    result <- tempfile('csgo-sql-result-', fileext = '.rds')
    on.exit(unlink(c(settings, result)), add = TRUE)
    saveRDS(list(root = demo_root, libraries = .libPaths()), settings)
    worker <- file.path(demo_root, 'presentation', 'sql_worker.R')
    executable <- file.path(R.home('bin'), if (.Platform$OS.type == 'windows') 'Rscript.exe' else 'Rscript')
    output <- suppressWarnings(system2(executable,
      args = c('--vanilla', shQuote(worker), shQuote(settings), shQuote(result)),
      stdout = TRUE, stderr = TRUE))
    if (!file.exists(result)) stop('SQLite worker did not return rows. Details: ', paste(tail(output, 8), collapse = '\n'))
    answer <- readRDS(result)
    cat('\nSQLite retrieval in an isolated R worker\n')
    cat('Tables:', paste(answer$tables, collapse = ', '), '\n')
    cat('\nActual import audit from SQLite\n'); print(answer$audit)
    cat('\nFive stored events from one indexed match\n'); print(answer$events)
    attr(answer, 'worker_exit_status') <- if (is.null(attr(output, 'status'))) 0L else attr(output, 'status')
    invisible(answer)
  } else demo_database_direct(path)
}

#' Direct DBI implementation, used by the worker or explicitly with isolate=FALSE.
demo_database_direct <- function(path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  tables <- DBI::dbListTables(con)
  cat('\nSQLite tables\n'); print(tables)
  cat('\nActual import audit from SQLite\n')
  audit <- DBI::dbGetQuery(con, 'SELECT * FROM imports')
  print(audit)
  cat('\nFive stored events from one indexed match\n')
  match <- DBI::dbGetQuery(con, 'SELECT file FROM events LIMIT 1')$file[1]
  rows <- DBI::dbGetQuery(con,
    'SELECT map, wp, wp_type, hitbox, seconds, total_damage FROM events WHERE file = ? LIMIT ?',
    params = list(match, 5L))
  print(rows)
  invisible(list(tables = tables, audit = audit, events = rows))
}

#' Display all twelve measured models. These are saved production results.
demo_results <- function() {
  metrics <- utils::read.csv(file.path(demo_root, 'results', 'model_comparison.csv'))
  print(metrics[, c('model', 'validation_MAE', 'MAE', 'RMSE', 'R2', 'selected_by_validation')],
        row.names = FALSE, digits = 4)
  winner <- metrics[metrics$selected_by_validation, ]
  cat('\nSelected using validation:', winner$model, '\n')
  cat('Test MAE:', winner$MAE, '95% interval:', winner$MAE_lower, 'to', winner$MAE_upper, '\n')
  cat('Baseline improvement interval:', winner$improvement_lower, 'to', winner$improvement_upper,
      '\nHolm-adjusted p:', winner$p_holm, '\n')
  invisible(metrics)
}

#' Score held-out rows live with the saved XGBoost model and frozen preprocessing.
#' n rows are a demonstration batch, not a new full evaluation experiment.
demo_predict <- function(n = 10L) {
  if (length(n) != 1L || !is.finite(n) || n < 1 || n > 1000 || n != as.integer(n))
    stop('n must be an integer from 1 to 1000.')
  required <- file.path(demo_root, 'models', c('analysis_sample.rds', 'preprocessor.rds', 'xd_model.json'))
  if (!all(file.exists(required))) stop('Local trained artifacts missing. Prepare a production run before class.')
  manifest_path <- file.path(demo_root, 'output', 'run_manifest.json')
  if (!file.exists(manifest_path)) stop('Local run manifest missing. Prepare production before class.')
  manifest <- jsonlite::fromJSON(manifest_path)
  if (isTRUE(manifest$smoke) || manifest$selected_model != 'XGBoost')
    stop('This demo requires the prepared production XGBoost artifacts; do not mix them with smoke or another selected model.')
  if (!requireNamespace('xgboost', quietly = TRUE)) stop('Install the project packages before class.')
  helpers <- new.env(parent = globalenv())
  sys.source(file.path(demo_root, 'R', 'preprocess.R'), envir = helpers)
  sample <- as.data.frame(readRDS(required[1]))
  test <- head(sample[sample$split == 'test', , drop = FALSE], n)
  if (!nrow(test)) stop('No held-out rows in the local sample.')
  pre <- readRDS(required[2])
  # The portable booster JSON avoids deserializing a training-time R closure.
  model <- xgboost::xgb.load(required[3])
  matrix <- helpers$transform_features(test, pre)
  predicted <- as.numeric(predict(model, xgboost::xgb.DMatrix(matrix, nthread = 2L)))
  stopifnot(length(predicted) == nrow(test), all(is.finite(predicted)))
  result <- data.frame(map = test$map, weapon = test$wp, hitbox = test$hitbox,
                       actual = test$total_damage, xD = round(predicted, 3),
                       residual = round(test$total_damage - predicted, 3))
  cat('\nFresh predictions on held-out rows\n'); print(result, row.names = FALSE)
  cat('\nFeature matrix:', nrow(matrix), 'rows by', ncol(matrix), 'columns\n')
  cat('Batch MAE (demo rows only):', mean(abs(test$total_damage - predicted)), '\n')
  invisible(result)
}

#' Show an existing chart in the RStudio Plots pane, keeping production files intact.
demo_plot <- function(which = c('expected', 'residual', 'importance', 'eda')) {
  which <- match.arg(which)
  relative <- switch(which,
    expected = 'results/heatmaps/XGBoost/de_dust2_expected.png',
    residual = 'results/heatmaps/XGBoost/de_dust2_residual.png',
    importance = 'results/eda/feature_importance.png',
    eda = 'results/eda/weapon_class_counts.png')
  if (!requireNamespace('png', quietly = TRUE)) stop('Install png before class.')
  image <- png::readPNG(file.path(demo_root, relative))
  grid::grid.newpage()
  pane <- grDevices::dev.size('in')
  pane_aspect <- pane[1] / pane[2]
  image_aspect <- dim(image)[2] / dim(image)[1]
  grid::grid.raster(image, width = grid::unit(min(1, image_aspect / pane_aspect), 'npc'),
                    height = grid::unit(min(1, pane_aspect / image_aspect), 'npc'),
                    interpolate = FALSE)
  invisible(relative)
}

#' Open the offline results gallery and its Plotly links in the default browser.
demo_gallery <- function() {
  path <- normalizePath(file.path(demo_root, 'results', 'index.html'), winslash = '/', mustWork = TRUE)
  url <- if (.Platform$OS.type == 'windows') paste0('file:///', path) else paste0('file://', path)
  utils::browseURL(URLencode(url))
  invisible(path)
}

cat('DA2 helpers ready. Run demo_preflight(), demo_database(), demo_predict(),\n',
    'demo_results(), demo_plot("expected") and demo_gallery() one at a time.\n', sep = '')
