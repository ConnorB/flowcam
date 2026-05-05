NIMS_BASE_URL <- "https://api.waterdata.usgs.gov/nims/v0"

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
  lines <- if (file.exists(renviron)) readLines(renviron, warn = FALSE) else character(0)
  lines <- lines[!grepl("^API_USGS_PAT\\s*=", lines)]
  lines <- c(lines, paste0('API_USGS_PAT="', key, '"'))
  writeLines(lines, renviron)
  Sys.setenv(API_USGS_PAT = key)
  cli::cli_alert_success(
    "API key saved to {.path {renviron}}. Restart R or call {.run readRenviron('~/.Renviron')} in new sessions."
  )
  invisible(key)
}

#' Format a date/time value for NIMS API query parameters
#'
#' Accepts a POSIXct, POSIXlt, Date, or character string and returns a
#' character string in ISO 8601 format (`YYYY-MM-DDTHH:MM:SS`). Character
#' strings are passed through unchanged; the API accepts both ISO 8601 and
#' NIMS-standard date strings.
#'
#' @param dt A POSIXct, POSIXlt, Date, or character string, or `NULL`.
#' @param arg_name Name of the calling argument (for error messages).
#'
#' @return A character string, or `NULL` if `dt` is `NULL`.
#' @keywords internal
format_datetime <- function(dt, arg_name = deparse(substitute(dt))) {
  if (is.null(dt)) return(NULL)
  if (inherits(dt, c("POSIXct", "POSIXlt"))) {
    format(dt, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  } else if (inherits(dt, "Date")) {
    format(as.POSIXct(dt, tz = "UTC"), "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  } else if (is.character(dt) && length(dt) == 1L) {
    dt
  } else {
    cli::cli_abort(
      "{.arg {arg_name}} must be a POSIXct, Date, or character string, not {.cls {class(dt)}}."
    )
  }
}

#' Perform a request against the NIMS API
#'
#' Internal helper. Builds an httr2 request with the appropriate base URL,
#' User-Agent, optional API key header, and query parameters, then performs
#' the request and parses the JSON response body.
#'
#' @param endpoint Character string, e.g. `"/cameras"` or `"/listFiles"`.
#' @param query Named list of query parameters. `NULL` values are dropped.
#'
#' @return A parsed R object (list or vector) from the JSON response.
#' @keywords internal
nims_request <- function(endpoint, query = list()) {
  url <- paste0(NIMS_BASE_URL, endpoint)

  ua <- paste0(
    "httr2/", utils::packageVersion("httr2"),
    " flowcam/", utils::packageVersion("flowcam"),
    " (https://github.com/yourorg/flowcam)"
  )

  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, ua)

  key <- get_api_key()
  if (!is.null(key)) {
    req <- httr2::req_headers_redacted(req, `X-Api-Key` = key)
  }

  query <- query[!vapply(query, is.null, logical(1L))]
  if (length(query) > 0L) {
    req <- do.call(httr2::req_url_query, c(list(req), query))
  }

  req <- httr2::req_error(req, body = function(resp) {
    ct <- httr2::resp_content_type(resp)
    if (grepl("json", ct, fixed = TRUE)) {
      msg <- httr2::resp_body_json(resp)[["message"]]
    } else {
      body <- httr2::resp_body_string(resp)
      msg <- if (grepl("API_KEY_MISSING", body, fixed = TRUE)) {
        "API key missing. Register at <https://api.waterdata.usgs.gov/signup/> then call set_nims_key()."
      } else if (grepl("OVER_RATE_LIMIT", body, fixed = TRUE)) {
        "Rate limit exceeded. Call set_nims_key() to use an API key, or wait before retrying."
      } else {
        paste("HTTP", httr2::resp_status(resp), httr2::resp_status_desc(resp))
      }
    }
    msg
  })

  req <- httr2::req_timeout(req, seconds = 60)

  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}
