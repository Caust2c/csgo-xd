# Separate syllabus demonstrations: wrangling, SQL, static graphics, Plotly.
source('config.R')
check_packages(c('data.table', 'dplyr', 'tidyr', 'ggplot2', 'DBI', 'RSQLite', 'jsonlite'))
suppressPackageStartupMessages(library(ggplot2))

#' Save a compact static plot. No full event table is read into memory.
save_eda <- function(plot, name) {
  ggplot2::ggsave(file.path(OUTPUT_DIR, 'eda', paste0(name, '.png')), plot,
                 width = 9, height = 6, dpi = 120, bg = 'white')
}

make_visualizations <- function() {
  sample_path <- file.path(MODEL_DIR, 'analysis_sample.rds')
  if (!file.exists(sample_path)) stop('Run pipeline.R first.')
  d <- as.data.frame(readRDS(sample_path))
  theme_set(theme_minimal(base_size = 12))
  caption <- 'Map-balanced capped analysis sample; descriptive association only'
  # Module 2: vector filtering, list access, and lapply transformations.
  numeric_vectors <- lapply(d[c('total_damage', 'engagement_distance', 'seconds')], as.numeric)
  summaries <- lapply(numeric_vectors, function(v) summary(v[is.finite(v)]))
  capture.output(summaries, file = file.path(OUTPUT_DIR, 'eda', 'vector_list_summaries.txt'))
  # Modules 3/4: grouped summarise, left_join, pivot_longer and pivot_wider.
  grouped <- dplyr::summarise(dplyr::group_by(d, wp_type),
    events = dplyr::n(), mean_damage = mean(total_damage), .groups = 'drop')
  lookup <- dplyr::distinct(dplyr::select(d, wp, wp_type))
  weapon_counts <- dplyr::count(d, wp, sort = TRUE)
  joined <- dplyr::left_join(weapon_counts, lookup, by = 'wp', relationship = 'many-to-many')
  readr::write_csv(joined, file.path(OUTPUT_DIR, 'eda', 'weapon_join_demo.csv'))
  long <- tidyr::pivot_longer(grouped, cols = c(events, mean_damage),
                            names_to = 'measure', values_to = 'value')
  wide <- tidyr::pivot_wider(long, names_from = measure, values_from = value)
  readr::write_csv(long, file.path(OUTPUT_DIR, 'eda', 'summary_long.csv'))
  readr::write_csv(wide, file.path(OUTPUT_DIR, 'eda', 'summary_wide.csv'))
  # Module 6: expressive encodings and layouts.
  p <- ggplot(grouped, aes(reorder(wp_type, events), events)) + geom_col(fill = '#287d8e') +
    coord_flip() + labs(title = 'Recorded damage events by weapon class', x = NULL, y = 'Sample events', caption = caption)
  save_eda(p, 'weapon_class_counts')
  save_eda(ggplot(d, aes(total_damage)) + geom_histogram(binwidth = 5, fill = '#287d8e', colour = 'white') +
    labs(title = 'Damage per hostile-player event', x = 'Health plus armor damage', y = 'Sample events', caption = caption), 'damage_histogram')
  save_eda(ggplot(d, aes(wp_type, total_damage)) + geom_boxplot(outlier.alpha = .1) + coord_flip() +
    labs(title = 'Damage distributions by weapon class', x = NULL, y = 'Damage', caption = caption), 'damage_boxplots')
  save_eda(ggplot(d, aes(factor(round_phase, levels = c('early', 'mid', 'late')), total_damage)) +
    geom_boxplot(outlier.alpha = .1, fill = '#9acbd3') +
    labs(title = 'Damage by parser-time bin', subtitle = '<=20, 20-60, >60 seconds; timing semantics require verification',
         x = 'Time bin', y = 'Damage', caption = caption), 'timing_boxplots')
  top <- head(weapon_counts, 15L)
  save_eda(ggplot(top, aes(reorder(wp, n), n)) + geom_col(fill = '#287d8e') + coord_flip() +
    labs(title = 'Most frequent weapons', x = NULL, y = 'Sample events', caption = caption), 'top_weapons')
  set.seed(SEED)
  small <- d[sample.int(nrow(d), min(nrow(d), 3000L)), ]
  save_eda(ggplot(small, aes(engagement_distance, total_damage, colour = wp_type)) + geom_point(alpha = .25, size = .6) +
    scale_x_continuous(trans = 'log1p') + labs(title = 'Range and damage by weapon class',
      x = 'Horizontal distance (log1p scale)', y = 'Damage', caption = caption), 'distance_scatter')
  cor_matrix <- stats::cor(as.data.frame(numeric_vectors), use = 'complete.obs')
  cor_long <- as.data.frame(as.table(cor_matrix))
  names(cor_long) <- c('x', 'y', 'r')
  save_eda(ggplot(cor_long, aes(x, y, fill = r)) + geom_tile() + geom_text(aes(label = sprintf('%.2f', r))) +
    scale_fill_gradient2(low = '#2166ac', high = '#b2182b', limits = c(-1, 1)) +
    labs(title = 'Numeric feature correlations', x = NULL, y = NULL, caption = caption), 'correlation_matrix')
  # Module 5: actual SQL query against the complete imported database.
  con <- DBI::dbConnect(RSQLite::SQLite(), DB_PATH)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  map_summary <- DBI::dbGetQuery(con,
    'SELECT map, COUNT(*) AS events, AVG(total_damage) AS mean_damage FROM events GROUP BY map ORDER BY events DESC')
  readr::write_csv(map_summary, file.path(OUTPUT_DIR, 'eda', 'sql_map_summary.csv'))
  save_eda(ggplot(map_summary, aes(reorder(map, events), events)) + geom_col(fill = '#287d8e') + coord_flip() +
    labs(title = 'Map event counts retrieved from SQLite', x = NULL, y = 'Imported events',
      caption = if (SMOKE) 'Smoke database subset' else 'All cleaned rows from both ESEA damage parts'), 'database_map_counts')
  results <- readr::read_csv(file.path(OUTPUT_DIR, 'model_comparison.csv'), show_col_types = FALSE)
  baseline_metrics <- jsonlite::fromJSON(file.path(OUTPUT_DIR, 'baseline_metrics.json'))
  save_eda(ggplot(results, aes(reorder(model, MAE), MAE)) + geom_point() +
    geom_hline(yintercept = baseline_metrics$metrics$MAE, linetype = 2, colour = '#287d8e') +
    geom_errorbar(aes(ymin = MAE_lower, ymax = MAE_upper), width = .2) + coord_flip() +
    labs(title = 'Test MAE with match-bootstrap 95% intervals', x = NULL, y = 'MAE (damage points)',
      caption = 'Dashed line: weapon-hitbox baseline. Selection uses validation MAE.'), 'model_comparison')
  winner <- readLines(file.path(OUTPUT_DIR, 'selected_model.txt'), warn = FALSE)[1]
  predictions <- readr::read_csv(file.path(OUTPUT_DIR, 'test_predictions.csv'), show_col_types = FALSE)
  predictions$expected <- predictions[[winner]]
  predictions$residual <- predictions$actual - predictions$expected
  save_eda(ggplot(predictions, aes(expected, residual)) + geom_point(alpha = .15, size = .5) +
    geom_hline(yintercept = 0, linetype = 2) + labs(title = paste(winner, 'held-out residual diagnostics'),
      x = 'Predicted damage', y = 'Actual minus predicted'), 'residual_diagnostics')
  predictions$decile <- dplyr::ntile(predictions$expected, 10L)
  calibration <- dplyr::summarise(dplyr::group_by(predictions, decile),
    expected = mean(expected), actual = mean(actual), events = dplyr::n(), .groups = 'drop')
  readr::write_csv(calibration, file.path(OUTPUT_DIR, 'eda', 'regression_calibration.csv'))
  save_eda(ggplot(calibration, aes(expected, actual)) + geom_abline(slope = 1, intercept = 0, linetype = 2) +
    geom_point(aes(size = events), colour = '#287d8e') +
    labs(title = 'Regression calibration by predicted-damage decile', x = 'Mean predicted damage', y = 'Mean actual damage'), 'regression_calibration')
  imp_path <- file.path(OUTPUT_DIR, 'permutation_importance.csv')
  if (winner != 'WeaponHitboxBaseline' && file.exists(imp_path)) {
    imp <- readr::read_csv(imp_path, show_col_types = FALSE)
    imp <- head(imp[order(-imp$validation_MAE_increase), ], 15L)
    save_eda(ggplot(imp, aes(reorder(feature, validation_MAE_increase), validation_MAE_increase)) +
      geom_col(fill = '#287d8e') + coord_flip() + labs(title = 'Selected model validation permutation importance',
        x = NULL, y = 'MAE increase after shuffling'), 'feature_importance')
  }
  # Module 7: optional interactive Plotly graphs, saved as offline HTML assets.
  if (requireNamespace('plotly', quietly = TRUE) && requireNamespace('htmlwidgets', quietly = TRUE)) {
    interactive <- list(weapon_classes = p,
      distance = ggplot(small, aes(engagement_distance, total_damage, colour = wp_type)) +
        geom_point(alpha = .3) + labs(title = 'Explore range and damage', x = 'Game units', y = 'Damage'),
      models = ggplot(results, aes(model, MAE, text = paste(model, 'test MAE', round(MAE, 3)))) + geom_col())
    for (name in names(interactive)) htmlwidgets::saveWidget(plotly::ggplotly(interactive[[name]]),
      file.path(OUTPUT_DIR, 'eda', paste0(name, '_interactive.html')), selfcontained = FALSE)
  } else warning('Plotly/htmlwidgets missing; static EDA is complete but Module 7 HTML was skipped.')
  # Reproducible JSON parsing demonstration. No authenticated Kaggle API is required.
  manifest <- jsonlite::fromJSON(file.path(OUTPUT_DIR, 'run_manifest.json'))
  writeLines(paste('Parsed run manifest; selected model:', manifest$selected_model),
             file.path(OUTPUT_DIR, 'eda', 'json_demo.txt'))
  message('Static and interactive syllabus visualizations saved to output/eda/.')
}
make_visualizations()
