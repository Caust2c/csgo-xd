# One model at a time, held-out match predictions only, bounded spatial grids.
source('config.R')
check_packages(c('data.table', 'ggplot2', 'png'))
suppressPackageStartupMessages(library(data.table))

#' Read independent X/Y radar bounds (do not average unequal scales).
read_calibration <- function() {
  path <- file.path(DATA_DIR, 'map_data.csv')
  if (!file.exists(path)) return(list())
  raw <- fread(path)
  setnames(raw, names(raw)[1], 'map')
  needed <- c('map', 'StartX', 'EndX', 'StartY', 'EndY', 'ResX', 'ResY')
  if (!all(needed %in% names(raw))) stop('map_data.csv has unexpected calibration columns.')
  out <- lapply(seq_len(nrow(raw)), function(i) {
    r <- raw[i]
    numeric_names <- needed[-1]
    values <- as.numeric(unlist(r[, ..numeric_names], use.names = FALSE))
    if (any(!is.finite(values)) || r$ResX <= 0 || r$ResY <= 0 ||
        r$StartX == r$EndX || r$StartY == r$EndY) return(NULL)
    list(xmin = min(r$StartX, r$EndX), xmax = max(r$StartX, r$EndX),
         ymin = min(r$StartY, r$EndY), ymax = max(r$StartY, r$EndY))
  })
  setNames(out, raw$map)
}

#' Bin on a fixed radar grid and export support rather than estimating a costly KDE.
spatial_grid <- function(d, bounds, bins = GRID_BINS) {
  dx <- (bounds$xmax - bounds$xmin) / bins
  dy <- (bounds$ymax - bounds$ymin) / bins
  inside <- d[att_pos_x >= bounds$xmin & att_pos_x <= bounds$xmax &
                att_pos_y >= bounds$ymin & att_pos_y <= bounds$ymax]
  outside <- nrow(d) - nrow(inside)
  inside[, `:=`(ix = pmin(bins - 1L, floor((att_pos_x - bounds$xmin) / dx)),
                 iy = pmin(bins - 1L, floor((att_pos_y - bounds$ymin) / dy)))]
  cells <- inside[, .(events = .N, matches = uniqueN(file),
                     actual = mean(total_damage), expected = mean(expected_damage),
                     residual = mean(xd_difference)), by = .(ix, iy)]
  cells[, `:=`(x = bounds$xmin + (ix + .5) * dx,
                 y = bounds$ymin + (iy + .5) * dy)]
  list(cells = cells, outside = outside, dx = dx, dy = dy)
}

#' Plot radar-aligned values; bins with fewer than five events/two matches are hidden.
draw_heatmap <- function(grid, bounds, map_name, model, type, use_radar = TRUE) {
  cells <- copy(grid$cells)
  cells[, value := get(type)]
  if (type != 'events') cells[events < MIN_BIN_EVENTS | matches < 2L, value := NA_real_]
  # Drop unsupported rows before applying fixed alpha; alpha would otherwise
  # make the transparent NA fill opaque white in some graphics devices.
  cells <- cells[is.finite(value)]
  p <- ggplot2::ggplot()
  image_path <- file.path(DATA_DIR, paste0(map_name, '.png'))
  has_radar <- use_radar && file.exists(image_path)
  if (has_radar) p <- p + ggplot2::annotation_raster(png::readPNG(image_path),
    xmin = bounds$xmin, xmax = bounds$xmax, ymin = bounds$ymin, ymax = bounds$ymax)
  p <- p + ggplot2::geom_tile(data = cells, ggplot2::aes(x, y, fill = value),
    width = grid$dx, height = grid$dy, alpha = .75, na.rm = TRUE)
  if (type == 'residual') {
    p <- p + ggplot2::scale_fill_gradient2(low = '#2166ac', mid = '#f7f7f7', high = '#b2182b',
      midpoint = 0, limits = c(-100, 100), oob = scales::squish, na.value = 'transparent', name = 'Actual - xD')
  } else {
    p <- p + ggplot2::scale_fill_viridis_c(option = 'inferno',
      limits = if (type == 'events') NULL else c(0, 200), oob = scales::squish, na.value = 'transparent',
      name = if (type == 'events') 'Sample count' else 'Damage')
  }
  p + ggplot2::coord_fixed(xlim = c(bounds$xmin, bounds$xmax),
    ylim = c(bounds$ymin, bounds$ymax), expand = FALSE) +
    ggplot2::labs(title = paste(map_name, model, type, sep = ' | '),
      subtitle = 'Held-out matches | attacker locations | xD is conditional on a recorded hit',
      caption = sprintf('Means require >=%d events and >=2 matches. Outside bounds: %d. %s',
        MIN_BIN_EVENTS, grid$outside, if (has_radar) 'Archive radar; calibration from map_data.csv.' else 'World-coordinate schematic; no calibrated radar.'),
      x = 'Game X', y = 'Game Y') + ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = 'white', colour = NA),
      plot.caption = ggplot2::element_text(size = 7))
}

render_heatmaps <- function() {
  files <- sort(list.files(file.path(MODEL_DIR, 'predictions'), '\\.rds$', full.names = TRUE))
  if (!length(files)) stop('Run pipeline.R first.')
  # Remove only this renderer's previous PNG/grid outputs; retain unrelated files.
  old_outputs <- list.files(file.path(OUTPUT_DIR, 'heatmaps'),
    '_(expected|residual|actual|events|grid)[.](png|csv)$', recursive = TRUE, full.names = TRUE)
  if (length(old_outputs)) unlink(old_outputs)
  calibration <- read_calibration()
  logs <- list()
  common_done <- character()
  for (path in files) {
    model <- sub('\\.rds$', '', basename(path))
    d <- as.data.table(readRDS(path))
    folder <- file.path(OUTPUT_DIR, 'heatmaps', model)
    dir.create(folder, showWarnings = FALSE)
    for (map_name in sort(unique(d$map))) {
      dm <- d[map == map_name]
      bounds <- calibration[[map_name]]
      calibrated <- !is.null(bounds)
      if (!calibrated) {
        xr <- range(dm$att_pos_x); yr <- range(dm$att_pos_y)
        bounds <- list(xmin = xr[1] - 1, xmax = xr[2] + 1, ymin = yr[1] - 1, ymax = yr[2] + 1)
      }
      grid <- spatial_grid(dm, bounds)
      fwrite(grid$cells, file.path(folder, paste0(map_name, '_grid.csv')))
      types <- c('expected', 'residual')
      if (!map_name %in% common_done) types <- c(types, 'actual', 'events')
      for (type in types) {
        target <- if (type %in% c('actual', 'events')) file.path(OUTPUT_DIR, 'heatmaps') else folder
        p <- draw_heatmap(grid, bounds, map_name,
                         if (type %in% c('actual', 'events')) 'Observed sample' else model,
                         type, use_radar = calibrated)
        ggplot2::ggsave(file.path(target, paste0(map_name, '_', type, '.png')),
          p, width = 8, height = 7, dpi = 120, bg = 'white')
      }
      common_done <- union(common_done, map_name)
      logs[[length(logs) + 1L]] <- data.table(model = model, map = map_name,
        events = nrow(dm), outside_bounds = grid$outside,
        cells = nrow(grid$cells), supported_cells = sum(grid$cells$events >= MIN_BIN_EVENTS & grid$cells$matches >= 2L),
        calibrated = calibrated)
    }
    message('Rendered heatmaps for ', model)
    rm(d)
    gc(verbose = FALSE)
  }
  fwrite(rbindlist(logs), file.path(OUTPUT_DIR, 'heatmap_support.csv'))
}
render_heatmaps()
