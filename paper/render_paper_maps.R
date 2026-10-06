# Compact, publication-sized panels from the same frozen held-out spatial caches.
# Load only function definitions from the heatmap entry script to avoid rerendering
# all 224 full-size gallery files while generating manuscript illustrations.
source('config.R')
check_packages(c('data.table', 'ggplot2', 'png'))
library(data.table)
for (expression in parse(file.path(PROJECT_ROOT, 'heatmaps.R'))) {
  if (is.call(expression) && identical(expression[[1]], as.name('<-')) &&
      as.character(expression[[2]]) %in% c('read_calibration', 'spatial_grid', 'draw_heatmap'))
    eval(expression)
}
target <- file.path(PROJECT_ROOT, 'paper', 'figures', 'panels')
dir.create(target, recursive = TRUE, showWarnings = FALSE)
calibration <- read_calibration()[['de_dust2']]
paths <- list.files(file.path(MODEL_DIR, 'predictions'), '[.]rds$', full.names = TRUE)
for (path in paths) {
  model <- sub('[.]rds$', '', basename(path))
  d <- as.data.table(readRDS(path))[map == 'de_dust2']
  grid <- spatial_grid(d, calibration)
  for (type in if (model == 'XGBoost') c('expected', 'actual', 'residual', 'events') else 'expected') {
    title <- if (type == 'expected') model else switch(type,
      actual = 'Observed damage', residual = 'Actual minus xD', events = 'Event support')
    p <- draw_heatmap(grid, calibration, 'de_dust2', model, type) +
      ggplot2::labs(title = title, subtitle = NULL, caption = NULL, x = NULL, y = NULL) +
      ggplot2::theme(axis.text = ggplot2::element_blank(), axis.ticks = ggplot2::element_blank(),
        plot.title = ggplot2::element_text(size = 10, hjust = .5, face = 'bold'),
        legend.title = ggplot2::element_text(size = 7), legend.text = ggplot2::element_text(size = 7),
        legend.key.height = grid::unit(.22, 'in'), legend.key.width = grid::unit(.1, 'in'),
        plot.margin = ggplot2::margin(2, 2, 2, 2))
    ggplot2::ggsave(file.path(target, paste0(model, '_', type, '.png')), p,
                   width = 3.1, height = 3, dpi = 240, bg = 'white')
  }
}
message('Saved manuscript panels at their intended physical print size.')
