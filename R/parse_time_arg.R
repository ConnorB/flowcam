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
  if (is.null(ts) || !nzchar(ts)) {
    return(NULL)
  }
  s <- sub(
    "^(\\d{4}-\\d{2}-\\d{2})T(\\d{2})-(\\d{2})-(\\d{2})Z?$",
    "\\1 \\2:\\3:\\4",
    ts
  )
  if (s == ts) {
    s <- sub("^(\\d{4}-\\d{2}-\\d{2})T(\\d{2}:\\d{2}:\\d{2})Z?$", "\\1 \\2", ts)
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

#' Build a dataRetrieval-compatible time vector from a flowcam time argument
#'
#' @param time `NULL`, a POSIXct/Date/character vector of length 1 or 2, or an
#'   ISO 8601 duration string (e.g. `"P7D"`).
#' @return A character vector to pass as the `time` argument to
#'   `read_waterdata_continuous()` or `read_waterdata_daily()`.
#' @keywords internal
.build_dr_time <- function(time) {
  if (is.null(time)) {
    return(NA_character_)
  }
  # ISO 8601 duration — pass through unchanged
  if (is.character(time) && length(time) == 1L && grepl("^[Pp]", time)) {
    return(time)
  }
  # Validate and normalise via parse_time_arg, then reconstruct for dataRetrieval
  tr <- parse_time_arg(time)
  if (is.null(tr$after) && is.null(tr$before)) {
    return(NA_character_)
  }
  if (is.null(tr$after)) {
    return(c(NA_character_, tr$before))
  }
  if (is.null(tr$before)) {
    return(tr$after)
  }
  c(tr$after, tr$before)
}
