# A short-lived native database backend for the Windows classroom demo.
# Called by demo_database(), not normally sourced by the presenter.
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) stop('Worker requires settings and result paths.')
settings <- readRDS(arguments[1])
.libPaths(settings$libraries)
setwd(settings$root)
source('presentation/live_demo.R')
answer <- demo_database(isolate = FALSE)
# Write query results after dbDisconnect(), before native process termination.
saveRDS(answer, arguments[2])
cat('SQLite queries and disconnect completed.\n')
