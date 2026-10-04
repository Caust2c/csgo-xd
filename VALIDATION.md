# Validation on the supplied archive

## DA2 demonstration check on 7 October 2026

The eight-slide PowerPoint was rendered in PowerPoint and all slides reviewed. Its tables and four charts remain editable. The Windows demo helpers checked visible installed-package versions, retrieved real SQLite rows, made fresh predictions using the portable XGBoost JSON and frozen preprocessor, displayed a production PNG, and read the comparison metrics. The combined presenter R process completed with native exit status zero after isolating database access.

A separate minimal test discovered a native shutdown access violation when loading the project-local RSQLite 3.53.3 Windows binary. Query results and disconnect completed before the fault; refreshing the same CRAN binary did not resolve it. The Windows classroom helper therefore uses an isolated R worker for DBI/RSQLite retrieval and returns data after disconnect. The worker exit status remains available as an attribute. This contains the observed fault for the presenter session, but does not repair the backend or establish clean full-pipeline shutdown. See `presentation/Professor_Preparation.md` for the limitation and demonstration steps. The original numerical result snapshot is unchanged. Native RStudio GUI execution has not been directly automated here.

## Original analysis validation

Validation was completed on 6 October 2026 using the installed Windows R 4.6.1 runtime. The pipeline is written with portable relative paths and includes Linux RStudio instructions, but it has **not been executed on a native Linux machine here**. Linux package compilation and distribution-specific system dependencies need checking on the target machine. No peak native-process RAM measurement was captured; the memory controls are implemented bounds on chunks, samples, model sizes, threading and grid resolution, not an absolute RAM limit.

Both ESEA damage CSV parts were imported into SQLite: 10,538,182 raw rows, with 10,279,321 retained after documented cleaning. The default model sample contained 59,763 events; fitting used 20,000 training rows, validation 8,000 rows, and testing 8,000 rows from 32 distinct held-out matches. The database occupies approximately 2.17 GB on disk. Modeling deliberately does not load or train on all imported events.

All 12 algorithms succeeded in both the initial smoke run and the production sample run. A fresh R process checked match split disjointness, excluded target features, finite predictions, independently recalculated MAE/RMSE, interval ordering, adjusted p-values, every saved model's predictions on 100 held-out rows, and spatial support invariants. These checks passed; see `output/verification.txt` and `verify_results.R`. All 13 R source files passed syntax parsing. The optional public GitHub REST/JSON example succeeded.

The output includes 224 heatmap PNGs across eight held-out maps, 12 separate static EDA PNGs, and three Plotly HTML files with accompanying asset folders. Expected/residual radar figures and the model comparison plot were visually inspected. The check caught and corrected opaque rendering of unsupported bins. Another check caught and corrected GAM's batch-dependent prediction discretization. Generated gallery links were checked for missing local targets and passed.

Validation MAE selected XGBoost. Its test MAE is 9.116 damage points, with a match-bootstrap 95% interval of 8.764 to 9.465. R squared is 0.701. The simple weapon-hitbox baseline's MAE is 9.167. The improvement interval crosses zero and the Holm-adjusted p-value is 0.6866; this run does not establish that XGBoost improves on the baseline. The measured report is `output/analysis_report.md`; package versions and settings are in `output/run_manifest.json`.

The outputs estimate conditional expected damage, xD. The supplied CSVs do not provide reliable per-player lethal/nonlethal opportunity labels for a calibrated xK model. This scope and the roadmap to xK are documented in README.md. The original research DOCX remains unchanged.

The source ZIP contains scripts, project settings and documentation only. It excludes the archive, databases, platform-specific package libraries, saved models and generated plots. Extract it alongside your archive on Linux, open `csgo_xD.Rproj`, and follow README.md.
