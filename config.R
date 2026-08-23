# Open csgo_xD.Rproj or setwd() to this directory before sourcing scripts.
PROJECT_ROOT <- normalizePath(Sys.getenv('CSGO_PROJECT_ROOT', unset = getwd()),
                              winslash = '/', mustWork = TRUE)
if (!file.exists(file.path(PROJECT_ROOT, 'csgo_xD.Rproj')))
  stop('Open csgo_xD.Rproj, or setwd() to the folder containing it.')
local_lib <- file.path(PROJECT_ROOT, '.R-library')
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
data_candidates <- file.path(PROJECT_ROOT, c('archive (3)', 'archive'))
DATA_DIR <- Sys.getenv('CSGO_DATA_DIR', unset = '')
if (!nzchar(DATA_DIR)) {
  found <- data_candidates[dir.exists(data_candidates)]
  if (!length(found)) stop('Set CSGO_DATA_DIR to the extracted Kaggle archive.')
  DATA_DIR <- found[1]
}
DATA_DIR <- normalizePath(DATA_DIR, winslash = '/', mustWork = TRUE)
OUTPUT_DIR <- file.path(PROJECT_ROOT, 'output')
MODEL_DIR <- file.path(PROJECT_ROOT, 'models')
DB_DIR <- file.path(PROJECT_ROOT, 'database')
invisible(lapply(c(OUTPUT_DIR, MODEL_DIR, DB_DIR,
                  file.path(OUTPUT_DIR, 'heatmaps'), file.path(OUTPUT_DIR, 'eda')),
                 dir.create, recursive = TRUE, showWarnings = FALSE))
env_int <- function(name, default) {
  value <- suppressWarnings(as.integer(Sys.getenv(name, unset = as.character(default))))
  if (is.na(value) || value < 1L) stop(name, ' must be a positive integer.')
  value
}
SEED <- 42L
CHUNK_ROWS <- env_int('CSGO_CHUNK_ROWS', 50000L)
SAMPLE_ROWS <- env_int('CSGO_SAMPLE_ROWS', 60000L)
FIT_ROWS <- env_int('CSGO_FIT_ROWS', 20000L)
MAX_PER_MATCH <- env_int('CSGO_MAX_PER_MATCH', 250L)
THREADS <- env_int('CSGO_THREADS', 2L)
BOOTSTRAPS <- env_int('CSGO_BOOTSTRAPS', 500L)
SMOKE <- identical(Sys.getenv('CSGO_SMOKE', unset = '0'), '1')
DB_PATH <- file.path(DB_DIR, if (SMOKE) 'csgo_smoke.sqlite' else 'csgo.sqlite')
if (SMOKE) {
  SAMPLE_ROWS <- min(SAMPLE_ROWS, 6000L)
  FIT_ROWS <- min(FIT_ROWS, 3000L)
  BOOTSTRAPS <- min(BOOTSTRAPS, 100L)
}
GRID_BINS <- 40L
MIN_BIN_EVENTS <- 5L
NUMERIC_FEATURES <- c('engagement_distance', 'log_distance', 'seconds',
                      'att_pos_x', 'att_pos_y', 'vic_pos_x', 'vic_pos_y',
                      'is_bomb_planted')
CAT_FEATURES <- c('map', 'wp', 'wp_type', 'hitbox', 'att_side', 'bomb_site', 'round_phase')
RAW_COLS <- c('file', 'round', 'tick', 'seconds', 'att_side', 'vic_side',
              'hp_dmg', 'arm_dmg', 'is_bomb_planted', 'bomb_site', 'hitbox',
              'wp', 'wp_type', 'att_pos_x', 'att_pos_y', 'vic_pos_x', 'vic_pos_y')
REQUIRED_PACKAGES <- c('data.table', 'DBI', 'RSQLite', 'readr', 'ggplot2',
                       'dplyr', 'tidyr', 'glmnet', 'ranger', 'gbm', 'earth',
                       'png', 'jsonlite', 'nnet', 'mgcv', 'rpart', 'xgboost')
check_packages <- function(pkgs = REQUIRED_PACKAGES) {
  absent <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) stop('Run 00_install_packages.R. Missing: ', paste(absent, collapse = ', '))
}
