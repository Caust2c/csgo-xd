# RStudio source() and Rscript entry point, run from the project directory.
source('config.R')
source(file.path(PROJECT_ROOT, 'database.R'))
source(file.path(PROJECT_ROOT, 'pipeline.R'))
source(file.path(PROJECT_ROOT, 'heatmaps.R'))
source(file.path(PROJECT_ROOT, 'visualizations.R'))
source(file.path(PROJECT_ROOT, 'report.R'))
message('Finished. See output/, models/, and README.md.')
