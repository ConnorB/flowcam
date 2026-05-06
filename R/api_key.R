#' Retrieve the USGS API key from the environment
#'
#' Reads `API_USGS_PAT` from the environment. Returns `NULL` (not `""`) when
#' unset, following the same convention as `dataRetrieval`.
#'
#' @return A single character string, or `NULL` if the variable is unset.
#' @keywords internal
get_api_key <- function() {
  key <- Sys.getenv("API_USGS_PAT")
  if (nzchar(key)) key else NULL
}

#' Store your USGS API key in .Renviron
#'
#' Writes `API_USGS_PAT` to `~/.Renviron` and applies it immediately in the
#' current session. The same variable is used by the `dataRetrieval` package,
#' so one key covers both packages.
#'
#' Register for a free key at <https://api.waterdata.usgs.gov/signup/>.
#'
#' @param key A single non-empty character string containing your API key.
#'
#' @return `key`, invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' set_nims_key("my_api_key_here")
#' }
set_nims_key <- function(key) {
  if (!is.character(key) || length(key) != 1L || !nzchar(key)) {
    cli::cli_abort("{.arg key} must be a single non-empty character string.")
  }
  renviron <- path.expand("~/.Renviron")
  lines <- if (file.exists(renviron)) {
    readLines(renviron, warn = FALSE)
  } else {
    character(0)
  }
  lines <- lines[!grepl("^API_USGS_PAT\\s*=", lines)]
  lines <- c(lines, paste0('API_USGS_PAT="', key, '"'))
  writeLines(lines, renviron)
  Sys.setenv(API_USGS_PAT = key)
  cli::cli_alert_success(
    "API key saved to {.path {renviron}}. Restart R or call {.run readRenviron('~/.Renviron')} in new sessions."
  )
  invisible(key)
}
