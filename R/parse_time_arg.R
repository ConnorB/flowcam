# Format a date/time value for a NIMS API query.
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

# Parse a NIMS or ISO 8601 timestamp into UTC POSIXct.
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

# Parse a time argument into NIMS after/before strings.
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

# Build a dataRetrieval-compatible time vector.
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
