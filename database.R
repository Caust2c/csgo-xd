# Chunked disk-backed ingestion. No full damage CSV is held in memory.
source('config.R')
check_packages(c('DBI', 'RSQLite', 'readr', 'data.table', 'jsonlite'))
data.table::setDTthreads(THREADS)

#' Open SQLite with a 64 MiB cache and disk-based temporary tables.
open_db <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), DB_PATH)
  DBI::dbExecute(con, 'PRAGMA cache_size=-65536')
  DBI::dbExecute(con, 'PRAGMA temp_store=FILE')
  con
}

#' Stream CSV using explicit character types to avoid parser type guessing.
stream_csv <- function(path, callback, columns) {
  header <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE))
  absent <- setdiff(columns, header)
  if (length(absent)) stop(basename(path), ' missing: ', paste(absent, collapse = ', '))
  types <- do.call(readr::cols_only, setNames(lapply(columns, function(x) readr::col_character()), columns))
  if (SMOKE) {
    callback(readr::read_csv(path, n_max = max(CHUNK_ROWS, 250000L), col_types = types,
                            show_col_types = FALSE), 1L)
    return(invisible(NULL))
  }
  readr::read_csv_chunked(path,
    callback = readr::SideEffectChunkCallback$new(callback),
    chunk_size = CHUNK_ROWS, col_types = types, progress = interactive())
  invisible(NULL)
}

#' Filter hostile-player damage and engineer features. Missing damage is not zero.
clean_events <- function(x, metadata) {
  d <- data.table::as.data.table(x)
  for (col in c('round', 'tick', 'seconds', 'hp_dmg', 'arm_dmg',
               'att_pos_x', 'att_pos_y', 'vic_pos_x', 'vic_pos_y'))
    data.table::set(d, j = col, value = suppressWarnings(as.numeric(d[[col]])))
  valid_sides <- c('CounterTerrorist', 'Terrorist')
  d <- d[att_side %in% valid_sides & vic_side %in% valid_sides & att_side != vic_side]
  d <- d[is.finite(hp_dmg) & hp_dmg >= 0 & hp_dmg <= 100 &
           is.finite(arm_dmg) & arm_dmg >= 0 & arm_dmg <= 100 & hp_dmg + arm_dmg > 0]
  d <- d[is.finite(seconds) & seconds >= 0 & is.finite(round) & is.finite(tick)]
  for (col in c('att_pos_x', 'att_pos_y', 'vic_pos_x', 'vic_pos_y'))
    d <- d[is.finite(get(col))]
  d <- d[!(att_pos_x == 0 & att_pos_y == 0) & !(vic_pos_x == 0 & vic_pos_y == 0)]
  for (col in c('wp', 'wp_type', 'hitbox'))
    d <- d[!is.na(get(col)) & !get(col) %in% c('', 'Unknown', 'Unkown', '8')]
  d[, map := metadata$map[match(file, metadata$file)]]
  d <- d[!is.na(map) & nzchar(map)]
  d[is.na(bomb_site) | bomb_site == '', bomb_site := 'none']
  planted <- tolower(as.character(d$is_bomb_planted))
  d[, is_bomb_planted := as.integer(planted %in% c('true', '1'))]
  d[, total_damage := hp_dmg + arm_dmg]
  d[, engagement_distance := sqrt((att_pos_x - vic_pos_x)^2 + (att_pos_y - vic_pos_y)^2)]
  d[, log_distance := log1p(engagement_distance)]
  # Parser timing is ambiguous; these are timing bins, not tactical phase claims.
  d[, round_phase := ifelse(seconds <= 20, 'early', ifelse(seconds <= 60, 'mid', 'late'))]
  d
}

#' Import atomically per file. Interrupted files roll back; completed files are reused.
build_database <- function() {
  damage <- sort(list.files(DATA_DIR, '^esea_master_dmg_demos\\.part[12]\\.csv$', full.names = TRUE))
  meta_paths <- sort(list.files(DATA_DIR, '^esea_meta_demos\\.part[12]\\.csv$', full.names = TRUE))
  if (!length(damage) || !length(meta_paths)) stop('Missing ESEA damage or metadata files.')
  con <- open_db()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(con, 'CREATE TABLE IF NOT EXISTS imports (source TEXT PRIMARY KEY, size REAL, mtime REAL, raw_rows INTEGER, clean_rows INTEGER)')
  for (path in damage) {
    part <- sub('.*(part[12]).*', '\\1', basename(path))
    meta_path <- meta_paths[grepl(part, basename(meta_paths), fixed = TRUE)]
    if (length(meta_path) != 1L) stop('Expected one metadata file for ', part)
    info <- file.info(c(path, meta_path))
    stamp <- sum(as.numeric(info$mtime))
    imported <- DBI::dbGetQuery(con, 'SELECT * FROM imports WHERE source=?', params = list(basename(path)))
    if (nrow(imported)) {
      if (imported$size != sum(info$size) || imported$mtime != stamp)
        stop('Inputs changed. Move database/ aside and rebuild.')
      message('Reusing imported ', basename(path))
      next
    }
    metadata <- data.table::fread(meta_path, select = c('file', 'map'))
    conflicts <- metadata[, .(n_maps = data.table::uniqueN(map)), by = file][n_maps != 1L]
    if (nrow(conflicts)) stop('Conflicting maps in metadata.')
    metadata <- unique(metadata, by = 'file')
    raw_rows <- 0L
    clean_rows <- 0L
    message('Streaming ', basename(path))
    DBI::dbWithTransaction(con, {
      stream_csv(path, function(x, pos) {
        raw_rows <<- raw_rows + nrow(x)
        d <- clean_events(x, metadata)
        if (SMOKE) {
          keep <- head(unique(d$file), 30L)
          d <- d[file %in% keep, head(.SD, 100L), by = file]
        }
        clean_rows <<- clean_rows + nrow(d)
        if (nrow(d)) DBI::dbWriteTable(con, 'events', as.data.frame(d), append = TRUE)
        message('  raw=', raw_rows, ' retained=', clean_rows)
        if (SMOKE) return(FALSE)
        invisible(NULL)
      }, RAW_COLS)
      DBI::dbExecute(con, 'INSERT INTO imports VALUES (?, ?, ?, ?, ?)',
        params = list(basename(path), sum(info$size), stamp, raw_rows, clean_rows))
    })
    rm(metadata)
    gc(verbose = FALSE)
  }
  if (!DBI::dbExistsTable(con, 'events')) stop('No usable events.')
  DBI::dbExecute(con, 'CREATE INDEX IF NOT EXISTS events_file ON events(file)')
  data.table::fwrite(DBI::dbGetQuery(con,
    'SELECT map, wp_type, COUNT(*) AS events, AVG(total_damage) AS mean_damage FROM events GROUP BY map, wp_type'),
    file.path(OUTPUT_DIR, 'database_summary.csv'))
  data.table::fwrite(DBI::dbReadTable(con, 'imports'), file.path(OUTPUT_DIR, 'import_audit.csv'))
  invisible(DB_PATH)
}
build_database()
