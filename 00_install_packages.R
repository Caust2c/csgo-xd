# Run once from the project root. A local library avoids admin privileges.
dir.create('.R-library', showWarnings = FALSE)
.libPaths(c(normalizePath('.R-library'), .libPaths()))
options(timeout = 600)
packages <- c('data.table', 'DBI', 'RSQLite', 'readr', 'ggplot2', 'dplyr',
              'tidyr', 'glmnet', 'ranger', 'gbm', 'earth', 'png', 'jsonlite',
              'plotly', 'htmlwidgets', 'nnet', 'mgcv', 'rpart', 'xgboost')
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  # Sequential downloads work on networks that reject many simultaneous requests.
  available <- available.packages(repos = 'https://cloud.r-project.org')
  visited <- character()
  ensure_package <- function(pkg) {
    if (requireNamespace(pkg, quietly = TRUE) || pkg %in% visited) return(invisible(NULL))
    visited <<- c(visited, pkg)
    dependencies <- tools::package_dependencies(pkg, db = available,
      which = c('Depends', 'Imports', 'LinkingTo'))[[pkg]]
    for (dep in setdiff(dependencies, 'R')) ensure_package(dep)
    install.packages(pkg, lib = .libPaths()[1], repos = 'https://cloud.r-project.org',
                     dependencies = FALSE, Ncpus = 1L)
  }
  for (pkg in missing) ensure_package(pkg)
}
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop('Installation incomplete: ', paste(missing, collapse = ', '))
message('All packages available. Run source("run_all.R").')
