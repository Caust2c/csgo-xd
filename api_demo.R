# Optional Module 5 REST/JSON example. Analysis does not require internet access.
# Run source('api_demo.R') separately; this is software metadata, not CS:GO telemetry.
source('config.R')
check_packages('jsonlite')
url <- 'https://api.github.com/repos/ValveSoftware/csgo-osx-linux'
target <- tempfile(fileext = '.json')
tryCatch({
  utils::download.file(url, target, quiet = TRUE, mode = 'wb',
                       headers = c('User-Agent' = 'csgo-xD-course-project',
                                   'Accept' = 'application/vnd.github+json'))
  result <- jsonlite::fromJSON(target)
  fields <- result[c('full_name', 'description', 'html_url', 'updated_at', 'open_issues_count')]
  jsonlite::write_json(fields, file.path(OUTPUT_DIR, 'eda', 'github_api_metadata.json'),
                       auto_unbox = TRUE, pretty = TRUE)
  message('REST response parsed and saved. This optional live response is time-dependent.')
}, error = function(e) warning('Optional API demo unavailable: ', conditionMessage(e)),
finally = if (file.exists(target)) unlink(target))
