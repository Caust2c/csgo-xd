# DA2 presentation and professor question preparation

Use `DA2_CS_GO_xD.pptx` for the eight-slide presentation. Its speaker notes contain a spoken explanation for each slide. Use this guide to rehearse the Windows demonstration and answer technical questions.

## The explanation to remember

“We estimate the expected health-plus-armor damage of a recorded hostile-player hit in CS:GO. We stream both CSV parts into SQLite, retrieve a bounded match sample, engineer features and compare twelve regression methods. Separate matches provide validation and test data. We plot predicted damage and actual-minus-predicted residuals at attacker locations. XGBoost has the best validation MAE, but this run does not establish that it outperforms a simple weapon-hitbox mean baseline.”

Use **xD, conditional expected damage**, throughout. The original xK idea is future work. This archive cannot supply a reliable calibrated kill-opportunity target.

## DA2 coverage from the supplied project plan

The DA2 criteria appear on reference slides 11 and 12, under “Presentation 2”. The total is ten marks.

| Criterion | Marks | Presentation evidence | File or demonstration |
|---|---:|---|---|
| Feature engineering and selection | 1 | Slide 3 | `R/preprocess.R`, 56 saved features, validation permutation importance |
| Database connectivity and retrieval | 2 | Slide 2 and live demo | `database.R`, `DBI`, `RSQLite`, real `dbGetQuery()` |
| 10–15 ML/DL algorithms | 3 | Slide 4 | All 12 named regression methods completed |
| Hyperparameter tuning and optimization | 1 | Slide 4 | Validation MAE, bounded candidate grids and XGBoost early stopping |
| Comparative evaluation metrics | 1 | Slides 5 and 7 | MAE, RMSE, R squared and baseline comparison |
| Comparative visualizations | 1 | Slides 3, 5, 6 and 7 | Importance, calibration, model comparison and heatmaps |
| Progress demonstration and documentation | 1 | Slide 8 and live demo | Working database, live inference, report, README and GitHub |

The plan gives ROC, confusion matrices and precision-recall as examples. Our response is: “Our target is continuous damage. We therefore use regression metrics, calibration, residual diagnostics and feature importance. A confusion matrix would require us to define a different classification target.”

The reference requests 75% completion evidence. Show the completed core artifacts rather than invent a numerical completion percentage. Database retrieval, all twelve methods, tuning, evaluation, visualizations and the research report exist. Native Linux verification, peak native RAM measurement, repeated split experiments and true xK labels remain future work.

## Suggested speaking order

| Slide | Explanation | Suggested time |
|---|---|---:|
| 1 | Problem, target and xD scope | 45 seconds |
| 2 | Dataset, cleaning and SQLite | 65 seconds |
| 3 | Engineered features and training-only selection | 70 seconds |
| 4 | Twelve methods and concrete tuning examples | 75 seconds |
| 5 | Match separation and metric meaning | 85 seconds |
| 6 | Heatmap meaning and support thresholds | 70 seconds |
| 7 | Comparison, baseline uncertainty and separate EDA | 80 seconds |
| 8 | Progress and demo handoff | 50 seconds |

This is about nine minutes of explanation. Add a three to four minute demo if the professor allows it. DA2 itself does not specify a duration in the supplied section. For a shorter slot, reduce the model-family explanation and show only SQL retrieval, one prediction batch and one heatmap. Read detailed notes in PowerPoint using View > Notes or Presenter View.

## Windows RStudio setup before class

### On this laptop

The project is at `C:/Users/hardi/xgtoxkR`. It already has the raw archive, production SQLite database and fitted model files from the completed analysis. Do not delete them or start a full rebuild just before class.

1. Open RStudio. Use File > Open Project and select `C:/Users/hardi/xgtoxkR/csgo_xD.Rproj`, or double-click that project file.
2. In the Console pane, run `getwd()`. It should show the project directory. Opening an R file alone does not set the correct working directory.
3. Open `presentation/live_demo.R` in the Source editor. Run the source command below in the Console to load the demonstration functions.
4. Use Ctrl+Enter to send a selected line from the editor to the Console. Alternatively paste one command into the Console and press Enter. Do not click Source on `run_all.R` during a short demo unless you intentionally want a full pipeline run.

```r
getwd()
R.version.string
source("presentation/live_demo.R")
demo_preflight()
```

`demo_preflight()` reports the nineteen requested package versions, the working directory and whether the local database and prediction artifacts exist. A package marked MISSING means it is unavailable to this R session, which can also mean a library-path or R-version mismatch.

If needed, install packages **before class**, with internet access:

```r
source("00_install_packages.R")
source("presentation/live_demo.R")
demo_preflight()
```

The installer uses `.R-library/` inside the project and skips packages already visible to R. Installed dependencies may also live in your user library. It increases the download timeout and installs dependencies sequentially. Installing is different from attaching a package: `install.packages()` places code on disk, `library()` attaches a package, and `package::function()` calls a function explicitly. RStudio is the IDE, while R executes the code.

### On a new Windows machine

Install R and RStudio Desktop using their official downloads, then download/clone the repository and extract the Kaggle archive beside the project as `archive` or `archive (3)`. The GitHub download includes the report and result snapshot, but excludes raw data, SQLite and fitted models.

- [RStudio Desktop official download](https://posit.co/download/rstudio-desktop/)
- [R for Windows official download](https://cran.r-project.org/bin/windows/base/)
- [R package installation documentation](https://search.r-project.org/R/refmans/utils/html/install.packages.html)

Windows binary packages usually avoid compilation. If R requests source compilation for a package with compiled code, use the Rtools version matching your R installation. Rtools is a separate compiler toolchain, not an R package. See the official installation documentation linked above.

Prepare a full production run well before the demonstration:

```r
# Open csgo_xD.Rproj first.
source("00_install_packages.R")
Sys.unsetenv("CSGO_SMOKE")
# Only needed if your archive is outside this project:
# Sys.setenv(CSGO_DATA_DIR = "C:/Users/YourName/Downloads/archive")
source("run_all.R")
source("verify_results.R")
```

Full ingestion scans both damage files. Model fitting remains bounded at 20,000 training rows. Completion time depends on hardware and storage; no fixed runtime is promised. Allow several gigabytes of free disk space for the extracted archive, database, temporary files and models.

An optional smoke run exercises a prefix of each part and smaller models:

```r
Sys.setenv(CSGO_SMOKE = "1")
source("run_all.R")
```

Smoke and production use separate databases, but both write to `output/` and `models/`. A smoke run can replace local trained artifacts and outputs. Do it during preparation, then complete production again if you want the exact production demo. The committed `results/` snapshot remains unchanged. Never present smoke metrics as the paper's results.

## Classroom live demonstration

Run each command separately, explain its output, then continue. Do not paste the entire pipeline into the Console.

### 1. Show readiness and real database connectivity

```r
source("presentation/live_demo.R")
demo_preflight()
demo_database()
```

Say: “This opens our production database with a read-only DBI connection in an isolated R worker on Windows. It shows the actual tables and import audit, then retrieves five event rows using a parameterized query and the match index.”

Expected tables are `events` and `imports`. The audit should contain both CSV parts and their raw/retained counts. Example retrieved columns are map, weapon, weapon class, hitbox, time and total damage. The function disconnects automatically even if an error occurs.

On this laptop, the RSQLite 3.53.3 binary returns correct query data but caused a native access violation when its R process exited. Reinstalling the same CRAN binary did not change that behavior. The Windows demo therefore runs SQLite in a separate R worker, returns rows after disconnecting and keeps the main presenter session free of the SQLite DLL. This is live R/DBI retrieval, not a cached replacement. `sql_worker.R` contains the worker entry point. `demo_database_direct()` contains the actual DBI calls.

The worker can exit abnormally after writing valid results. The helper exposes that status as an attribute rather than treating it as a successful shutdown:

```r
sql_result <- demo_database()
attr(sql_result, "worker_exit_status")
```

This isolates the observed issue for the classroom demo; it does not repair RSQLite or certify the full ingestion pipeline's shutdown behavior. The main demo does not call `quit()` or restart RStudio. Other builds may not have this issue. Rehearse the demonstration on the actual presentation machine.

On a compatible database build, the low-level connection can also run directly in the Console. On this laptop, prefer the isolated worker:

```r
con <- DBI::dbConnect(RSQLite::SQLite(),
                     "database/csgo.sqlite", flags = RSQLite::SQLITE_RO)
DBI::dbListTables(con)
DBI::dbGetQuery(con, "SELECT source, raw_rows, clean_rows FROM imports")
DBI::dbDisconnect(con)
```

Do not run an unnecessary full-table aggregate over ten million rows during the presentation. The demo's event lookup uses the match index and a small limit.

### 2. Make fresh model predictions

```r
demo_predict(10)
```

Say: “Training happened during preparation. Now we load the saved XGBoost model and frozen preprocessor and predict ten previously held-out rows live. The same 56-column encoding and scaling apply here.”

The demo loads the portable booster at `models/xd_model.json`, the saved preprocessor and the sampled held-out rows. The output gives `actual`, `xD` and `residual`. In the prepared production artifacts, the first example is a Dust2 Famas chest event with actual damage 22, xD about 19.909 and residual about +2.091. Another example is an AWP chest event with actual 101 and xD about 80.068. These are examples, not a claim that every event follows that value.

The batch has ten rows and 56 columns. Its printed batch MAE is **only for those ten rows**. The reported project test MAE 9.116 uses all 8,000 test rows. A saved model demonstration is live inference, not live retraining.

### 3. Show evaluation evidence

```r
demo_results()
```

Explain that all methods use the same held-out evaluation rows. Validation selects XGBoost. MAE is 9.116 damage points and R squared is approximately 0.701. The baseline is competitive and the paired improvement interval includes zero.

### 4. Show the spatial output and ordinary EDA

```r
demo_plot("expected")
demo_plot("residual")
demo_plot("importance")
demo_plot("eda")
```

These commands show **existing production figures** in the RStudio Plots pane. They do not regenerate the heatmaps. Use Plots > Zoom if the professor needs a larger view. Explain expected versus actual-minus-predicted color scales and the five-event/two-match support threshold. Then show ordinary EDA separately.

### 5. Show interactive plots and documentation

```r
demo_gallery()
```

The browser opens `results/index.html` locally. Follow an interactive Plotly link and hover over the chart. Keep its asset folders beside the HTML file. The local plots do not require internet. GitHub's file preview does not execute the HTML gallery. If the browser does not open automatically, open `results/index.html` from File Explorer.

Finish by showing the root README and research paper. If time is very limited, skip the full metrics printout and the extra EDA plots.

### If something fails during class

| Symptom | Likely cause | Response |
|---|---|---|
| “Open csgo_xD.Rproj” | Wrong working directory | Open the project and rerun `getwd()` |
| “There is no package called …” | Missing package or different library/R version | Show `demo_preflight()` and `.libPaths()`; install before class, not mid-demo |
| Database missing | Fresh clone excludes large artifacts | Use the saved result snapshot and state that live database retrieval needs a prepared local run |
| Saved model missing | Training artifacts absent or overwritten | Show saved production metrics and explain the limitation; do not call it live inference |
| Wrong results after smoke mode | `models/` and `output/` were replaced | Check `output/run_manifest.json`, restore/regenerate production during preparation |
| Interactive page blank | Missing HTML asset folder or GitHub preview | Open the local HTML with its `_files` directory intact |
| Windows path error | Backslashes interpreted as escapes | Use `C:/...` or double backslashes in R strings |
| Machine feels slow | Heavy pipeline running or many apps open | Stop the heavy run with Esc/Stop; demonstrate bounded retrieval and existing artifacts |

If packages exist in another library, inspect `.libPaths()` and use the actual library path on your machine. For this laptop a user library was available at `C:/Users/hardi/AppData/Local/R/win-library/4.6`. Do not copy that path to someone else's machine or load packages compiled for an incompatible R version. RStudio's R selection can differ from a command-line session. [Posit's R version guidance](https://support.posit.co/hc/en-us/articles/200486138-Changing-R-versions-for-the-RStudio-Desktop-IDE) explains this setting.

## Package list and what each one does

The versions below were observed in the prepared Windows R 4.6.1 environment. They document this run rather than force every machine to use the same versions. `demo_preflight()` prints the versions visible to your current session.

| Package | Observed version | Role |
|---|---|---|
| data.table | 1.18.4 | Fast cleaning, grouping, sample tables and grid aggregation |
| DBI | 1.3.0 | Common database connection/query interface |
| RSQLite | 3.53.3 | SQLite backend used through DBI |
| readr | 2.2.0 | Chunked CSV parsing and CSV outputs |
| ggplot2 | 4.0.3 | Static EDA and radar heatmaps |
| dplyr | 1.2.1 | Grouped summaries and joins in syllabus demonstrations |
| tidyr | 1.3.2 | Long/wide reshaping demonstrations |
| glmnet | 5.1 | Ridge, lasso and elastic net |
| ranger | 0.18.0 | Random forest and extremely randomized trees |
| gbm | 2.3.1 | Gradient boosted regression trees |
| earth | 5.3.6 | Multivariate adaptive regression splines, MARS |
| png | 0.1.9 | Reading radar backgrounds and displaying saved figures |
| jsonlite | 2.0.0 | JSON manifests and optional API response parsing |
| plotly | 4.12.1 | Interactive charts created from ggplot objects |
| htmlwidgets | 1.6.4 | Saving Plotly HTML and dependency assets |
| nnet | 7.3.20 | Small neural network for continuous output |
| mgcv | 1.9.4 | Generalized additive model using `bam()` |
| rpart | 4.1.27 | CART regression tree |
| xgboost | 3.2.1.1 | Histogram gradient boosting and saved model inference |

Base/recommended R functionality also supplies `stats`, `utils`, `tools`, `grid` and functions such as `mean()`, `lapply()`, `set.seed()`, `readRDS()` and `saveRDS()`. OLS uses `stats::lm.fit()`. We use individual packages rather than requiring the whole tidyverse, caret or tidymodels. We do not implement Shiny or an R Markdown rendering workflow; the project generates its measured Markdown report directly. The reference lists possible technology choices, not evidence that all of them appear in our code.

## Professor questions and short answers

### Problem and data

**1. What exactly does your project do?**
It estimates damage conditional on an observed hit and its context, compares twelve regressors on separate matches and maps predicted damage and residuals. It also provides independent EDA and interactive plots.

**2. What is your research question?**
Do extra spatial, timing and context predictors improve conditional damage prediction over a simple weapon-hitbox average? How can we display errors spatially while showing where the sample supports a mean?

**3. Why CS:GO?**
The supplied archive contains event-level combat telemetry with map positions. It lets us study a measurable outcome and spatial diagnostics. Our results describe this historical CS:GO archive and do not establish generalization to CS2.

**4. What is xD mathematically?**
The target is `y = hp_dmg + arm_dmg`. The model estimates `E[y | recorded hit, available context]`. xD has units of damage points.

**5. Why include armor damage?**
It follows the original project's combined-damage definition. That combination measures a recorded event amount, not remaining health or lethality. A future analysis could compare health-only and combined targets.

**6. Why can total damage exceed 100?**
Health and armor damage are separate components. Their sum can exceed 100 even when each component is within the cleaning bounds. The observed sample range is 1 to 127.

**7. Is xD divided by 100 equal to expected kills?**
No. Kill probability needs reliable lethal/nonlethal opportunity labels, pre-hit health and opportunity information. Damage ratios do not provide calibrated probabilities.

**8. What is the dataset and its size?**
Kaggle's CS:GO Competitive Matchmaking Data archive. Both ESEA damage parts provide 10,538,182 raw events. Cleaning retains 10,279,321. The bounded analysis sample contains 59,763 events from 240 matches and eight maps.

**9. What does one row represent?**
A recorded damage event with match, round/tick, weapon, hitbox, sides, parser time and positions. It does not represent every shot or every possible engagement.

**10. What cleaning did you apply?**
We require opposing sides, finite usable numeric values, valid context, each damage component between 0 and 100 and positive total damage. We remove unusable paired-zero coordinate sentinels and invalid weapon/hitbox categories. Missing bomb-site labels become “none”. Full rules are in `clean_events()` in `database.R`.

**11. How do you handle missing values?**
We reject events missing necessary outcome, position or context information instead of inventing damage values. Categorical fallback happens during encoding. Matrix construction replaces nonfinite entries with zero defensively, after the data-cleaning rules. Dropped records and fallback encoding are limitations.

**12. Is your sample random and representative?**
It is seeded and reproducible, balances sampled matches across maps and caps events per match. SQL uses deterministic tick/round pseudo-random ordering. We do not claim a proven uniform event sample. EDA shares describe this sample, not full-population frequencies.

**13. Why do you use a sample after storing ten million rows?**
SQLite gives reproducible access to the full cleaned archive. Bounded modeling prevents a large dense matrix and excessive fitting memory. Full-import SQL summaries and sample-based models answer different questions.

### Database and R implementation

**14. How does database connectivity work?**
DBI provides `dbConnect()`, `dbGetQuery()` and `dbDisconnect()`. RSQLite implements those operations for a local SQLite file. We stream cleaned CSV chunks into `events`, keep the import audit in `imports` and retrieve sampled matches with SQL.

**15. Why SQLite rather than MySQL?**
SQLite runs locally without a separate server or credentials, fits a portable student project and stores large data on disk. The DA2 rubric accepts SQLite. A multi-user service could justify a server database later.

**16. Where is the SQL actually used?**
Import auditing, filename-indexed match retrieval, sampled event selection and full-import grouped summaries. `demo_database()` retrieves actual stored events instead of merely printing a SQL string.

**17. Why use parameterized queries?**
The match filename and limit travel as values, not SQL text pasted together. This handles quoting safely and makes the query reusable.

**18. What happens if import stops halfway?**
A per-file transaction rolls back the incomplete part. The import audit marks completed parts. File size and modification time help detect changed inputs, but they are not cryptographic integrity checks. If the cleaning rules change, rebuild the database.

**19. How do you make the project modular?**
`config.R` supplies paths and bounds, `database.R` ingests data, `pipeline.R` samples and fits, `R/preprocess.R` transforms features, `R/models.R` defines adapters and `R/statistics.R` evaluates. `heatmaps.R`, `visualizations.R` and `report.R` generate outputs. `run_all.R` orchestrates the workflow.

**20. What does a function do in this project?**
It names a reusable operation with inputs and a result. For example, `transform_features(test, pre)` applies exactly the preprocessing learned on training rows. `fit_algorithm()` returns a common model/prediction interface despite different packages.

**21. Where do lists, vectors and lapply appear?**
Lists hold models, category levels and result collections. Numeric vectors hold predictions and feature centers/scales. `lapply()` applies retrieval or transformation logic across matches or columns. Vectorized comparisons, arithmetic and matrix operations avoid an R loop for every event.

**22. Why use data.table and dplyr together?**
data.table handles the repeated cleaning/grouping efficiently. dplyr and tidyr provide readable syllabus examples for summaries, joins and long/wide reshaping. They have distinct roles rather than duplicating the full pipeline.

**23. Do you use a web API?**
The optional `api_demo.R` retrieves public GitHub repository metadata and parses JSON with jsonlite. It demonstrates REST/JSON separately. Kaggle authentication and a live API call are unnecessary for the core analysis or offline class demo.

### Features and leakage

**24. What features did you engineer?**
Planar engagement distance, `log1p(distance)`, bomb indicator and parser-time bins. Map identity, weapon, weapon class, hitbox and attacker side provide additional context.

**25. What is feature engineering versus selection?**
Engineering creates useful variables such as distance. Selection removes unsuitable or redundant columns, such as constants and numeric columns with absolute training correlation above .98. The result is 56 encoded predictors.

**26. How do you encode categorical variables?**
One-hot columns represent training levels, with one reference level omitted. We retain at most 25 training levels per field. Rare or unseen values receive the all-zero reference representation. That fallback loses distinctions and is a limitation.

**27. Why scale variables?**
Distance and coordinate units differ from binary indicators. Training-based standardization makes the inputs suitable for regularization and neural fitting. Trees do not require scaling, but the shared matrix keeps the comparison consistent.

**28. How do you prevent leakage?**
Matches do not overlap between partitions. Encoding, variance filtering, correlation filtering and scaling use the common training subset. Outcomes and player IDs do not enter predictors. Validation controls tuning; test data remain outside fitting and model selection.

**29. Does the hitbox feature leak information?**
Hitbox is available after the recorded hit, so it is valid for our retrospective conditional damage target. It would be inappropriate to claim pre-shot effectiveness from this model. Its strong predictive role is one reason the simple baseline performs well.

**30. Why exclude victim side and player IDs?**
With opposing-side filtering, victim side is redundant given attacker side. Player IDs could encourage identity-specific patterns and are outside this contextual damage objective. Match identity groups splits, not predictions.

**31. What does feature importance mean?**
For the selected model, we shuffle one encoded feature on validation rows and measure the MAE increase. A larger increase indicates reliance on that feature. It is not a causal effect, and correlated features can make interpretation difficult.

### Models and tuning

**32. Which twelve algorithms did you implement?**
OLS, ridge, lasso, elastic net, CART, random forest, extra trees, GBM, XGBoost, MARS, GAM and a neural network. The weapon-hitbox mean is an additional baseline. We count related algorithm variants transparently, not twelve unrelated families.

**33. How does each method work at a basic level?**

| Method | Plain explanation |
|---|---|
| OLS | Fits a linear combination by minimizing squared errors |
| Ridge | Adds an L2 penalty that shrinks linear coefficients |
| Lasso | Adds an L1 penalty that can set coefficients to zero |
| Elastic net | Combines L1 and L2 penalties |
| CART | Splits predictor space into regions with simple predictions |
| Random forest | Averages many regression trees built with randomness |
| Extra trees | Uses additional split randomization in the tree ensemble |
| GBM | Adds trees sequentially to improve the previous fit |
| XGBoost | Implements regularized boosted trees with efficient training |
| MARS | Fits adaptive piecewise spline basis functions |
| GAM | Combines smooth effects with other model terms |
| Neural network | Learns a small nonlinear mapping through hidden units |

**34. Is your neural network deep learning?**
It has one hidden layer with five or ten units. Describe it as a shallow neural network, not a deep architecture. The rubric permits ML or DL and we implement twelve ML regression methods.

**35. How do you tune hyperparameters?**
We compare small predefined candidates using validation MAE. For glmnet, validation chooses lambda along the fitted path. CART compares complexity .005/.02, forests compare node size 10/30, GBM compares depth 2/4, XGBoost compares depth 3/5, MARS compares degree 1/2 and the network compares size 5/10.

**36. How does early stopping work?**
XGBoost monitors validation MAE and stops after twenty rounds without improvement, within a 250-round maximum. That helps bound unnecessary fitting. The selected candidate has depth five. It does not prove the globally best hyperparameters.

**37. Why train methods sequentially?**
Training multiple large models at once increases peak memory. Sequential fitting and two threads help keep the task practical on a 16 GB machine.

**38. What is the baseline?**
For each weapon-hitbox pair we compute mean total damage on the same fitting subset. An unseen pair uses the global training mean. It tests whether more complex models add useful information beyond basic weapon and impact context.

### Validation and statistics

**39. How do you split the data?**
We split match identities approximately 70/15/15 within maps where possible. This run has 176 training, 32 validation and 32 test matches. The training partition has 43,763 rows, of which 20,000 form the shared fitting subset. Validation and test each have 8,000 rows.

**40. Why split by match instead of event?**
Events from the same match share players, context and conditions. Mixing them across training and testing could make the evaluation overly optimistic. Match separation limits that dependence across partitions.

**41. Which method wins and why?**
XGBoost has the smallest validation MAE, 8.897. We use that rule to select it before reporting test performance. Its test MAE is 9.116, RMSE 14.692 and R squared .701.

**42. What do the metrics mean?**
MAE is the mean absolute prediction error in damage points. RMSE is the square root of mean squared error and penalizes large errors more. R squared is `1 - SSE/SST`, relative to predicting the test mean. R squared .701 does not mean 70.1% classification accuracy.

**43. Why is the baseline better on RMSE?**
The methods minimize different objectives and the selection rule uses validation MAE. The baseline test RMSE is 14.674 versus XGBoost 14.692. Metric rankings can differ; we disclose that rather than change the selection rule after seeing test values.

**44. Is XGBoost significantly better than the baseline?**
This run does not establish that. The paired MAE improvement is .050768 damage points, with a 95% interval from -.017952 to .122959. The Holm-adjusted p-value is .6866. The interval crosses zero.

**45. How did you calculate uncertainty?**
We resample the 32 test matches with replacement for 500 bootstrap replicates, keeping their event contributions together. This preserves sampled within-match dependence. The selected model's MAE interval is 8.764 to 9.465. It describes uncertainty conditional on this model/sample, not training refit uncertainty.

**46. What is the paired test and Holm adjustment?**
For each model we compare baseline versus model absolute errors on the same events. A match-level sign-flip randomization test uses 500 repeats. Holm correction accounts for twelve comparisons. A small p-value can also describe a model performing worse, so inspect the improvement sign.

**47. Why no ROC or confusion matrix?**
Our target is numeric damage, not a class. We use MAE/RMSE/R squared, regression calibration, residuals, importance and comparative heatmaps. A future true kill-probability model could use ROC, precision-recall, confusion matrices, Brier score and log loss with suitable labels.

**48. What checks prove that the exported results are consistent?**
`verify_results.R` checks disjoint match splits, excluded outcomes, finite predictions, independently recalculated metrics, interval order, adjusted p-values, all twelve saved-model reloads and grid support invariants. It verifies consistency, not universal generalization or causal validity.

### Heatmaps and interpretation

**49. How does a heatmap work here?**
We divide a map's calibrated world bounds into 40 by 40 cells. At attacker positions we group held-out events, then compute mean actual damage, mean predicted damage, mean residual and support counts. ggplot2 draws cells over the radar background.

**50. How do game coordinates match the image?**
`map_data.csv` supplies independent X/Y bounds. The renderer preserves unequal axis scales and upward game Y. A map without calibration uses a world-coordinate schematic. Radar alignment needs landmark validation before tactical use.

**51. What do red and blue residuals mean?**
Residual is actual minus xD. Positive/red means observed damage exceeded prediction; negative/blue means it fell below prediction. Near-zero indicates agreement. This can reflect missing context as well as model error.

**52. Why are some cells blank?**
Mean cells need at least five events from two matches. Missing or sparse cells are omitted. Blank areas do not imply safety or zero damage. Count layers retain occupied cells and communicate sample support.

**53. Why is this not a tactical recommendation?**
We observe selected damage events, without misses, exposure or remaining health. Location, weapon and hitbox can be confounded. Cell means have support thresholds but no cell-specific uncertainty intervals. Planar views mix floors. A causal tactical claim would need a different design.

**54. How many plots are there?**
224 spatial PNGs across eight test-represented maps. For twelve models plus the baseline, each map has expected and residual layers, plus shared actual/count layers. There are also twelve ordinary EDA PNGs and three Plotly HTML charts.

### Reproducibility, limitations and progress

**55. What makes it reproducible?**
Seed 42, saved sampling/split artifacts, fixed preprocessing, model objects, run settings, package versions, source scripts and documented execution. Package versions are recorded rather than fully locked, so a target-machine lockfile would improve long-term replication.

**56. Will it fit in 16 GB RAM?**
We control work sizes: 50,000-row CSV chunks, at most 60,000 sampled events, 20,000 fitting rows, sequential models, two threads and 40 by 40 grids. SQLite keeps full rows on disk. We did not measure peak native-process RAM, so we cannot promise an absolute maximum or guarantee no crash on every machine.

**57. What is new about it?**
The contribution is a reproducible, memory-conscious regression comparison with explicit SQLite retrieval, statistical validation and model-specific supported map diagnostics for this archive. We do not claim a new learning algorithm or a proven predictive advantage.

**58. What are the most important limitations?**
Recorded-hit selection, missing pre-hit health/armor and exposure, a map-balanced capped sample, one split, limited tuning, correlated predictors, sparse spatial support, planar geometry and conditional uncertainty. Native Linux execution and peak RAM measurement remain unverified.

**59. How would you improve it?**
Repeat grouped or temporal evaluation, include refitting uncertainty, measure memory, lock dependencies and add cell-level intervals/floor geometry. For xK, reparse demos to create reliable player-linked lethal/nonlethal opportunities including misses and pre-hit state, then evaluate probabilities separately.

**60. What did GitHub contribute?**
It stores the modular source, documentation, paper and small derived result snapshot. Raw data, local libraries, SQLite and models stay outside Git. The repository began with a consolidated project export; do not claim an invented weekly commit history. Record future actual changes with meaningful commits.

**61. What if the professor asks you to change an input live?**
The provided demo uses real held-out rows to avoid an artificial claim. You can increase `demo_predict(20)` up to 1,000 rows. Editing hitbox or weapon creates a hypothetical event and is not a causal experiment. Explain that before doing a counterfactual input demonstration.

**62. Can you regenerate a graph live?**
The shortest demo shows saved figures and fresh inference. Re-running `visualizations.R` or `heatmaps.R` regenerates outputs from local caches, but replaces their corresponding generated files. Do it only with enough time and prepared artifacts. Showing a saved PNG should be described honestly as viewing a production figure.

**If asked why SQLite uses a worker:** The local binary caused a crash on R process shutdown even in a minimal package-load test. We isolate the native backend so RStudio can continue to prediction and plots. The worker returns actual DBI query results after disconnecting, and its exit status remains inspectable. This is a local runtime limitation, not a claim that all RSQLite installations fail. A compatible backend build and separate full-pipeline retest remain the proper long-term repair.

## Values to memorize

| Item | Value |
|---|---|
| Seed | 42 |
| Raw / retained rows | 10,538,182 / 10,279,321 |
| Sample | 59,763 events, 240 matches, 8 maps |
| Train partition / actual fitting | 43,763 / 20,000 rows |
| Validation / test | 8,000 / 8,000 rows, 32 matches each |
| Encoded features | 56 |
| Algorithms | 12, plus a baseline |
| Selected method | XGBoost, by validation MAE |
| Test MAE / RMSE / R squared | 9.116 / 14.692 / .701 |
| MAE 95% interval | 8.764 to 9.465 |
| Baseline MAE | 9.167 |
| Improvement 95% interval | -.018 to .123 |
| Holm-adjusted p-value | .6866 |
| Heatmap support | 5 events and 2 matches |
| Resource bounds | 50,000-row chunks, 20,000 fitting rows, 2 threads |

Avoid claims of calibrated expected kills, classification accuracy, tactical causation, exhaustive tuning, statistically proven baseline superiority, measured peak RAM or native Linux testing. Explain those boundaries calmly and connect each one to the available data or validation design.

## Evidence to open if challenged

- Feature definitions: `config.R` and `R/preprocess.R`.
- Tuning choices: `R/models.R` and local `models/*_tuning.json`.
- Real database import/query: `database.R`, `pipeline.R`, `demo_database()`.
- Complete metrics and uncertainty: `results/model_comparison.csv` and `R/statistics.R`.
- Support thresholds and coordinate mapping: `heatmaps.R`.
- Checks: `verify_results.R` and `results/verification.txt`.
- Measured paper: `paper/CSGO_xD_Research_Paper.docx`.
- Public project: https://github.com/Caust2c/csgo-xd.

Project facts in this guide come from the measured results and implementation files. External setup references are the official R and Posit documentation linked above. The supplied project plan controls the DA2 coverage; its general examples are not claims about packages or features we implemented.
