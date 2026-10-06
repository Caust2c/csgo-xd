# Additional descriptive tables for the research manuscript, using the same sample.
source('config.R')
check_packages(c('data.table', 'jsonlite'))
library(data.table)
d <- as.data.table(readRDS(file.path(MODEL_DIR, 'analysis_sample.rds')))
dir.create(file.path(PROJECT_ROOT, 'paper', 'inputs'), recursive = TRUE, showWarnings = FALSE)
target <- file.path(PROJECT_ROOT, 'paper', 'inputs')
weapon <- d[, .(events = .N, mean = mean(total_damage), median = median(total_damage),
  q25 = as.numeric(quantile(total_damage, .25)), q75 = as.numeric(quantile(total_damage, .75))), by = wp_type]
setorder(weapon, -events)
fwrite(weapon, file.path(target, 'weapon_summary.csv'))
fwrite(d[, .(events = .N), by = hitbox][order(-events)], file.path(target, 'hitbox_summary.csv'))
fwrite(d[, .(events = .N, median = median(total_damage)), by = round_phase],
       file.path(target, 'timing_summary.csv'))
jsonlite::write_json(list(damage_mean = mean(d$total_damage), damage_median = median(d$total_damage),
  damage_min = min(d$total_damage), damage_max = max(d$total_damage),
  selected_feature_count = nrow(fread(file.path(OUTPUT_DIR, 'selected_features.csv'))),
  sample_matches = uniqueN(d$file), sample_maps = uniqueN(d$map),
  train_matches = uniqueN(d[split == 'train', file]), validation_matches = uniqueN(d[split == 'validation', file]),
  test_matches = uniqueN(d[split == 'test', file])), file.path(target, 'descriptive_stats.json'),
  auto_unbox = TRUE, pretty = TRUE)
message('Exported manuscript descriptive tables without refitting models.')
