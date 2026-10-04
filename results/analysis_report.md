# CS GO expected damage results

Run mode: **Full archive import with bounded model sample**

These are retrospective conditional expected-damage results, not calibrated kill probabilities. See README.md for execution, model definitions, statistical assumptions, and the xK roadmap.

SQLite ingestion covered 10,538,182 raw rows and retained 10,279,321 cleaned hostile-player damage rows.

The model sample contains 59763 events. Shared fitting used 20000 training rows, validation used 8000 rows, and testing used 8000 rows from 32 matches. The seed is 42 and there were 500 match-bootstrap replicates.

12 of 12 regression methods completed successfully.

Validation selected XGBoost. Held-out MAE is 9.116 damage points (match-bootstrap 95% interval 8.764 to 9.465), RMSE 14.692, and R squared 0.701. Its paired MAE improvement over the weapon-hitbox baseline is 0.051 (interval -0.018 to 0.123); Holm-adjusted randomization p-value 0.6866.

The simple training-only weapon-hitbox baseline has test MAE 9.167 and RMSE 14.674.

## Model comparison

| Method | Validation MAE | Test MAE | MAE 95% interval | Test RMSE | Test R squared |
|---|---:|---:|---|---:|---:|
| OLS | 9.045 | 9.217 | 8.878 to 9.571 | 14.831 | 0.696 |
| Ridge | 9.107 | 9.288 | 8.939 to 9.642 | 14.928 | 0.692 |
| Lasso | 9.049 | 9.227 | 8.888 to 9.583 | 14.835 | 0.696 |
| ElasticNet | 9.051 | 9.231 | 8.891 to 9.586 | 14.837 | 0.696 |
| CART | 10.162 | 10.394 | 10.052 to 10.732 | 15.446 | 0.670 |
| RandomForest | 9.514 | 9.712 | 9.371 to 10.083 | 15.134 | 0.683 |
| ExtraTrees | 9.533 | 9.740 | 9.378 to 10.117 | 15.197 | 0.681 |
| GBM | 9.067 | 9.263 | 8.932 to 9.608 | 14.685 | 0.702 |
| XGBoost | 8.897 | 9.116 | 8.764 to 9.465 | 14.692 | 0.701 |
| MARS | 9.176 | 9.404 | 9.073 to 9.773 | 14.810 | 0.697 |
| GAM | 9.047 | 9.212 | 8.870 to 9.569 | 14.832 | 0.696 |
| NeuralNet | 8.975 | 9.194 | 8.877 to 9.534 | 14.677 | 0.702 |

## Figures and interpretation

Open output/eda/model_comparison.png for confidence intervals, regression_calibration.png for predicted versus observed decile means, and residual_diagnostics.png for prediction errors. Ordinary weapon, timing and range charts are separate from map heatmaps. Interactive HTML includes zoom, pan and tooltips.

Held-out heatmaps cover 8 maps. There are 528 supported cells across the shared grid of the selected model; 0 test events lie outside supplied/schematic bounds.

The map-specific *_grid.csv files retain actual, predicted and residual means plus event and match support. Unsupported cells are transparent. Positive residuals describe unexpectedly high damage conditional on observed context; they do not establish tactical advantage or skill.

## Limits and next steps

The sample balances maps and caps rows per match, so sample frequencies are not population estimates. Hyperparameter tuning is small and test intervals are conditional on fitted models. One split cannot establish transfer to modern CS2 or professional matches. Match-level bootstrap and paired randomization respect sampled within-match dependence, but their assumptions and multiple-comparison limitations still apply.

Hit location is observed after impact. Remaining health, armor state, penetration, misses, exposure opportunities and height are absent. A true xK extension needs reliable per-player lethal/nonlethal opportunity labels and probability calibration. The supplied ESEA kill table cannot support a reliable per-player linkage from these CSVs alone.

Submission evidence: selected_features.csv, dropped_features.txt, database_summary.csv, import_audit.csv, match_splits.csv, model_status.csv, model_comparison.csv, heatmap_support.csv, run_manifest.json, and sessionInfo.txt. Review failures and support before choosing figures.
