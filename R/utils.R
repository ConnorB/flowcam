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

#' Normalise a USGS/NWIS site ID
#'
#' Accepts the bare numeric form (`"05366800"`) or the `USGS-` prefixed form
#' (`"USGS-05366800"`) and returns the plain 8-to-15-digit string expected by
#' the NIMS API.
#'
#' @param site_id A single character string.
#' @param arg_name Argument name used in error messages.
#'
#' @return A plain numeric site ID string.
#' @keywords internal
normalize_site_id <- function(site_id, arg_name = "site_id") {
  if (!is.character(site_id) || length(site_id) != 1L || !nzchar(site_id)) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a single non-empty character string."
    )
  }
  site_id <- sub("^USGS-", "", site_id, ignore.case = TRUE)
  if (!grepl("^\\d{8,15}$", site_id)) {
    cli::cli_abort(
      c(
        "{.arg {arg_name}} must be a NWIS site number (8-15 digits).",
        i = "Accepted formats: {.val 05366800} or {.val USGS-05366800}."
      )
    )
  }
  site_id
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
  if (is.null(dt)) {
    return(NULL)
  }
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

#' Parse a NIMS timestamp string into POSIXct
#'
#' Handles both the NIMS wire format (`"2022-09-12T19-30-10Z"`, dashes in the
#' time component) and standard ISO 8601 (`"2022-09-12T19:30:10Z"`).
#'
#' @param ts A single character string, or `NULL`.
#'
#' @return A POSIXct value (UTC), or `NULL` if `ts` is `NULL`, empty, or
#'   unparseable.
#' @keywords internal
.parse_nims_ts <- function(ts) {
  if (is.null(ts) || !nzchar(ts)) return(NULL)
  s <- sub("^(\\d{4}-\\d{2}-\\d{2})T(\\d{2})-(\\d{2})-(\\d{2})Z?$",
           "\\1 \\2:\\3:\\4", ts)
  if (s == ts) {
    s <- sub("^(\\d{4}-\\d{2}-\\d{2})T(\\d{2}:\\d{2}:\\d{2})Z?$",
             "\\1 \\2", ts)
  }
  r <- tryCatch(as.POSIXct(s, tz = "UTC"), error = function(e) NULL)
  if (!is.null(r) && !is.na(r)) r else NULL
}

#' Parse a dataRetrieval-style time argument into after/before strings
#'
#' Accepts `NULL`, a length-1 value (treated as start), or a length-2 vector
#' where `NA` elements indicate open-ended bounds.
#'
#' @param time `NULL`, or a POSIXct/Date/character vector of length 1 or 2.
#'
#' @return A named list with elements `after` and `before`, each a character
#'   string or `NULL`.
#' @keywords internal
parse_time_arg <- function(time) {
  if (is.null(time)) {
    return(list(after = NULL, before = NULL))
  }
  if (length(time) > 2L) {
    cli::cli_abort("{.arg time} must be length 1 or 2, not {length(time)}.")
  }

  fmt <- function(x, label) {
    if (length(x) == 1L && is.na(x)) {
      return(NULL)
    }
    format_datetime(x, label)
  }

  if (length(time) == 1L) {
    return(list(after = fmt(time, "time"), before = NULL))
  }

  after <- fmt(time[[1L]], "time[1]")
  before <- fmt(time[[2L]], "time[2]")

  if (!is.null(after) && !is.null(before)) {
    after_t <- tryCatch(as.POSIXct(after, tz = "UTC"), error = function(e) NULL)
    before_t <- tryCatch(as.POSIXct(before, tz = "UTC"), error = function(e) {
      NULL
    })
    if (!is.null(after_t) && !is.null(before_t) && after_t >= before_t) {
      cli::cli_abort("Start of {.arg time} must be earlier than the end.")
    }
  }

  list(after = after, before = before)
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
    "httr2/",
    utils::packageVersion("httr2"),
    " flowcam/",
    utils::packageVersion("flowcam"),
    " (https://connorb.github.io/flowcam/)"
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
