# Generate an evidence-based results note from the current run, without invented values.
source('config.R')
check_packages(c('data.table', 'jsonlite'))

write_results_report <- function() {
  manifest <- jsonlite::fromJSON(file.path(OUTPUT_DIR, 'run_manifest.json'))
  comparisons <- data.table::fread(file.path(OUTPUT_DIR, 'model_comparison.csv'))
  audit <- data.table::fread(file.path(OUTPUT_DIR, 'import_audit.csv'))
  support <- data.table::fread(file.path(OUTPUT_DIR, 'heatmap_support.csv'))
  baseline <- jsonlite::fromJSON(file.path(OUTPUT_DIR, 'baseline_metrics.json'))
  winner <- manifest$selected_model
  selected <- comparisons[model == winner]
  selection_text <- if (nrow(selected)) sprintf(
    'Validation selected %s. Held-out MAE is %.3f damage points (match-bootstrap 95%% interval %.3f to %.3f), RMSE %.3f, and R squared %.3f. Its paired MAE improvement over the weapon-hitbox baseline is %.3f (interval %.3f to %.3f); Holm-adjusted randomization p-value %.4f.',
    winner, selected$MAE, selected$MAE_lower, selected$MAE_upper, selected$RMSE, selected$R2,
    selected$MAE_improvement, selected$improvement_lower, selected$improvement_upper, selected$p_holm)
  else sprintf('The weapon-hitbox baseline was selected by validation. Its test MAE is %.3f.', baseline$metrics$MAE)
  header <- c('# CS GO expected damage results', '',
    paste('Run mode:', if (manifest$smoke) '**Smoke test subset**' else '**Full archive import with bounded model sample**'), '',
    'These are retrospective conditional expected-damage results, not calibrated kill probabilities. See README.md for execution, model definitions, statistical assumptions, and the xK roadmap.', '',
    sprintf('SQLite ingestion covered %s raw rows and retained %s cleaned hostile-player damage rows.',
      format(sum(audit$raw_rows), big.mark = ','), format(sum(audit$clean_rows), big.mark = ',')), '',
    sprintf('The model sample contains %s events. Shared fitting used %s training rows, validation used %s rows, and testing used %s rows from %s matches. The seed is %d and there were %d match-bootstrap replicates.',
      manifest$rows, manifest$fit_rows, manifest$validation_rows, manifest$test_rows,
      manifest$test_matches, manifest$seed, manifest$bootstrap_replicates), '',
    sprintf('%d of %d regression methods completed successfully.', manifest$successful_algorithms, manifest$requested_algorithms), '',
    selection_text, '',
    sprintf('The simple training-only weapon-hitbox baseline has test MAE %.3f and RMSE %.3f.',
      baseline$metrics$MAE, baseline$metrics$RMSE), '',
    '## Model comparison', '',
    '| Method | Validation MAE | Test MAE | MAE 95% interval | Test RMSE | Test R squared |',
    '|---|---:|---:|---|---:|---:|')
  rows <- vapply(seq_len(nrow(comparisons)), function(i) {
    r <- comparisons[i]
    sprintf('| %s | %.3f | %.3f | %.3f to %.3f | %.3f | %.3f |',
      r$model, r$validation_MAE, r$MAE, r$MAE_lower, r$MAE_upper, r$RMSE, r$R2)
  }, character(1))
  tail <- c('', '## Figures and interpretation', '',
    'Open output/eda/model_comparison.png for confidence intervals, regression_calibration.png for predicted versus observed decile means, and residual_diagnostics.png for prediction errors. Ordinary weapon, timing and range charts are separate from map heatmaps. Interactive HTML includes zoom, pan and tooltips.', '',
    sprintf('Held-out heatmaps cover %d maps. There are %d supported cells across the shared grid of the selected model; %d test events lie outside supplied/schematic bounds.',
      data.table::uniqueN(support$map), sum(support[model == winner, supported_cells]),
      sum(support[model == winner, outside_bounds])), '',
    'The map-specific *_grid.csv files retain actual, predicted and residual means plus event and match support. Unsupported cells are transparent. Positive residuals describe unexpectedly high damage conditional on observed context; they do not establish tactical advantage or skill.', '',
    '## Limits and next steps', '',
    'The sample balances maps and caps rows per match, so sample frequencies are not population estimates. Hyperparameter tuning is small and test intervals are conditional on fitted models. One split cannot establish transfer to modern CS2 or professional matches. Match-level bootstrap and paired randomization respect sampled within-match dependence, but their assumptions and multiple-comparison limitations still apply.', '',
    'Hit location is observed after impact. Remaining health, armor state, penetration, misses, exposure opportunities and height are absent. A true xK extension needs reliable per-player lethal/nonlethal opportunity labels and probability calibration. The supplied ESEA kill table cannot support a reliable per-player linkage from these CSVs alone.', '',
    'Submission evidence: selected_features.csv, dropped_features.txt, database_summary.csv, import_audit.csv, match_splits.csv, model_status.csv, model_comparison.csv, heatmap_support.csv, run_manifest.json, and sessionInfo.txt. Review failures and support before choosing figures.')
  writeLines(c(header, rows, tail), file.path(OUTPUT_DIR, 'analysis_report.md'))
  # A local gallery makes hundreds of saved figures easy to browse.
  maps <- sort(unique(support$map))
  charts <- c('model_comparison', 'damage_histogram', 'weapon_class_counts',
               'damage_boxplots', 'distance_scatter', 'regression_calibration')
  chart_html <- vapply(charts, function(name) sprintf(
    '<figure><a href="eda/%s.png"><img loading="lazy" src="eda/%s.png" alt="%s"></a><figcaption>%s</figcaption></figure>',
    name, name, name, gsub('_', ' ', name)), character(1))
  map_html <- vapply(maps, function(map_name) sprintf(
    '<figure><a href="heatmaps/%s/%s_expected.png"><img loading="lazy" src="heatmaps/%s/%s_expected.png" alt="%s expected damage"></a><figcaption>%s %s xD</figcaption></figure>',
    winner, map_name, winner, map_name, map_name, map_name, winner), character(1))
  links <- vapply(c(comparisons$model, 'WeaponHitboxBaseline'), function(model) {
    items <- vapply(maps, function(map_name) sprintf(
      '<li>%s: <a href="heatmaps/%s/%s_expected.png">xD</a> | <a href="heatmaps/%s/%s_residual.png">residual</a> | <a href="heatmaps/%s/%s_grid.csv">grid CSV</a></li>',
      map_name, model, map_name, model, map_name, model, map_name), character(1))
    paste0('<details><summary>', model, '</summary><ul>', paste(items, collapse = ''), '</ul></details>')
  }, character(1))
  html <- c('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
    '<title>CS GO expected damage results</title><style>body{font:16px system-ui,sans-serif;max-width:1200px;margin:30px auto;padding:0 20px;color:#20343d;background:#f8fafb}h1,h2{color:#142d36}a{color:#176b85}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:20px}figure{margin:0}img{width:100%;background:white;border:1px solid #d5dfe4}figcaption{padding:8px 0}details{padding:10px;border-bottom:1px solid #d5dfe4}summary{cursor:pointer;font-weight:600}li{margin:8px 0}</style>',
    '<body><h1>CS GO expected damage results</h1>',
    paste0('<p>', if (manifest$smoke) 'Smoke test subset.' else 'Full archive import with a bounded model sample.',
      ' ', manifest$successful_algorithms, ' regression methods completed. Validation selected ', winner, '.</p>'),
    '<p>xD is expected damage conditional on a recorded hit. Cell means require five events and two matches. These figures do not estimate kill probabilities or establish tactical causation.</p>',
    '<p><a href="analysis_report.md">Measured results report</a> | <a href="model_comparison.csv">Model metrics CSV</a> | <a href="run_manifest.json">Run settings</a> | <a href="heatmap_support.csv">Heatmap support</a></p>',
    '<h2>Separate data visualizations</h2><div class="gallery">', chart_html, '</div>',
    '<p>Interactive: <a href="eda/weapon_classes_interactive.html">weapon classes</a> | <a href="eda/distance_interactive.html">range and damage</a> | <a href="eda/models_interactive.html">model comparison</a></p>',
    '<h2>Selected model map heatmaps</h2><div class="gallery">', map_html, '</div>',
    '<h2>Every model and map</h2>', links, '</body></html>')
  writeLines(html, file.path(OUTPUT_DIR, 'index.html'))
}
write_results_report()
